defmodule Jido.Connect.Google.Meet.TestSupport.LiveMeet do
  @moduledoc """
  Skips the Meet live tests whose prepared meeting data Google has deleted.

  Google deletes a conference record, and the transcript entries under it,
  30 days after the conference ends. The prepared data of the test account
  dates from `@prepared_on`; once Google has deleted it, the live tests that
  read it cannot pass. A live test that reads prepared data adds a
  `prepared!/1` tag after its `env!/1` tag and lists the prepared items it
  reads. An item is one of the variables `GOOGLE_MEET_CONFERENCE_RECORD` and
  `GOOGLE_MEET_TRANSCRIPT`, or `:earlier_conference_record`, the earlier
  conference prepared on `@prepared_on` in the space of
  `GOOGLE_MEET_CONFERENCE_RECORD`. No variable names that record; its name is
  `@earlier_conference_record`. A recording lives under its conference
  record, so a test of a recording lists `GOOGLE_MEET_CONFERENCE_RECORD`. A
  test that also needs the earlier record lists `:earlier_conference_record`
  after `GOOGLE_MEET_CONFERENCE_RECORD`; Google deletes the earlier record
  first, and once both are gone the skip names the variable.

      alias Jido.Connect.Google.Meet.TestSupport.LiveMeet
      require LiveMeet

      @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
      @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
      test "pages through transcript entries", %{env: env} do
        ...
      end

  ExUnit decides skips from tags before any setup runs, so `prepared!/1`,
  like `env!/1`, runs when the test file compiles. It returns
  `[live_meet_prepared: items]` and adds `skip:` with a reason when an item
  names deleted data. It asks Google in every run with an include filter,
  such as `--only live_smoke`, `--include live_smoke`, `--only test:"..."`,
  `--only describe:"..."` or a location like `mix test <file>:<line>`. Each
  of them overrides the `:live_smoke` exclude for the tests it selects, and
  the tag runs before ExUnit knows the test's name and describe, so it cannot
  tell whether the filter selects this test. A plain `mix test` has no
  include filter and asks nothing, and neither does a run without
  `GOOGLE_ACCESS_TOKEN` or with the variable unset, which `env!/1` already
  skips. It checks the items in the given order and names the first one whose
  data is gone. Each record or transcript is asked once per VM, so a run with
  an include filter costs at most one request per item and value; the cache
  key holds no token. Any other item raises `ArgumentError` when the file
  compiles.

  `probe/3` sends a variable's request with `GOOGLE_ACCESS_TOKEN`:
  `conferenceRecords.get` with `fields=name` for
  `GOOGLE_MEET_CONFERENCE_RECORD`, and one page of `transcripts.entries.list`
  with the entry names only, no text, for `GOOGLE_MEET_TRANSCRIPT`. The
  earlier record gets the request of `GOOGLE_MEET_CONFERENCE_RECORD`.
  `probe/3` returns Google's answer as Req returns it, because the Meet
  client's `ProviderError` keeps neither Google's `error.status` nor the
  ErrorInfo reason.

  `expired?/1` reads two answers as deleted data: 404 `NOT_FOUND`, and 403
  `PERMISSION_DENIED` without an ErrorInfo reason whose message says the
  resource might not exist, Google's answer for a conference record that does
  not exist. Every other answer, among them success, 401, a 403 with
  `ACCESS_TOKEN_SCOPE_INSUFFICIENT`, 400, 5xx and transport errors, leaves the
  test to run and fail.

  Neither answer is unique to expired data. Google gives the 403 also for a
  record that exists but that the account of `GOOGLE_ACCESS_TOKEN` cannot
  see, and the 404 also for a transcript ID that never existed. A skip before
  the prepared data expires, 30 days after `@prepared_on`, therefore points
  at the configuration, such as a wrong ID or a token of another account. The
  404 rule still holds for `GOOGLE_MEET_TRANSCRIPT`: a transcript that the
  variable names and that no longer exists is gone data, and Google deletes
  transcript entries 30 days after the conference ends.

  The skip reason names the variable, or the earlier record as such,
  `@prepared_on`, the status, Google's `error.status` and the ErrorInfo
  reason or else Google's message, so the skip line shows Google's answer for
  the check that skipped. A run that asked Google prints it as the harness
  prints `env!/1` skips:

      live_smoke skip test/jido_connect/google/meet/live_smoke_test.exs:72: GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30, has expired: Google answered 403 PERMISSION_DENIED "Permission denied on resource Conference (or it might not exist)"; see "Prepared Meet data" in docs/live_smoke_tests.md
      live_smoke skip test/jido_connect/google/meet/live_smoke_test.exs:152: conferenceRecords/6EMiOc40YJH2mjvfx8U6DxIUOBEQAjIGCIoCIAAYAwg, the earlier conference prepared on 2026-10-30 in the space of GOOGLE_MEET_CONFERENCE_RECORD, has expired: Google answered 403 PERMISSION_DENIED "Permission denied on resource Conference (or it might not exist)"; see "Prepared Meet data" in docs/live_smoke_tests.md

  With fresh meeting data, change `@prepared_on` and
  `@earlier_conference_record`; "Prepared Meet data" in
  `docs/live_smoke_tests.md` lists what else changes with them.
  """

  alias Jido.Connect.Google.Meet.Client.Transport

  # The day the prepared Meet data was created. Change it with fresh data.
  @prepared_on ~D[2026-10-30]

  # The earlier conference prepared on @prepared_on in the space of
  # GOOGLE_MEET_CONFERENCE_RECORD, which the window, transcript list, meeting
  # code and earlier participants checks expect. No variable names it. Change
  # it with fresh data.
  @earlier_conference_record "conferenceRecords/6EMiOc40YJH2mjvfx8U6DxIUOBEQAjIGCIoCIAAYAwg"

  @variables ~w(GOOGLE_MEET_CONFERENCE_RECORD GOOGLE_MEET_TRANSCRIPT)
  @items @variables ++ [:earlier_conference_record]
  @error_info "type.googleapis.com/google.rpc.ErrorInfo"
  @docs ~s(see "Prepared Meet data" in docs/live_smoke_tests.md)

  @doc """
  Returns the tags of a live test that reads the prepared Meet `items`, with
  `skip:` when Google has deleted the data of one of them.

  An item is `"GOOGLE_MEET_CONFERENCE_RECORD"`, `"GOOGLE_MEET_TRANSCRIPT"` or
  `:earlier_conference_record`.
  """
  defmacro prepared!(items) do
    quote do
      Jido.Connect.Google.Meet.TestSupport.LiveMeet.prepared_tags(unquote(items), __ENV__)
    end
  end

  @doc false
  def prepared_tags(items, %Macro.Env{} = env) when is_list(items) do
    Enum.each(items, &known_item!/1)
    tags = [live_meet_prepared: items]

    case expired_item(items) do
      nil -> tags
      {item, answer} -> Keyword.put(tags, :skip, skip_reason(item, answer, env))
    end
  end

  @doc "Tells whether a result of `probe/3` is Google's answer for deleted data."
  @spec expired?({:ok, Req.Response.t()} | {:error, Exception.t()}) :: boolean()
  def expired?(result), do: match?({:expired, _answer}, classify(result))

  @doc "Sends the request that `prepared!/1` sends for `variable` with value `name`."
  @spec probe(String.t(), String.t(), String.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def probe(variable, name, access_token)

  def probe("GOOGLE_MEET_CONFERENCE_RECORD", name, access_token) do
    get(access_token, "/v2/" <> encode(name), fields: "name")
  end

  def probe("GOOGLE_MEET_TRANSCRIPT", name, access_token) do
    get(access_token, "/v2/" <> encode(name) <> "/entries",
      pageSize: 1,
      fields: "transcriptEntries(name)"
    )
  end

  # Clears the cache, for the offline tests of this module.
  @doc false
  def forget do
    for {{__MODULE__, _variable, _value} = key, _answer} <- :persistent_term.get() do
      :persistent_term.erase(key)
    end

    :ok
  end

  defp get(access_token, path, params) do
    access_token
    |> Transport.request()
    |> Req.get(url: path, params: params)
  end

  defp encode(name) do
    name
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode(&1, fn char -> URI.char_unreserved?(char) end))
  end

  defp expired_item(items) do
    access_token = System.get_env("GOOGLE_ACCESS_TOKEN")

    if live_run?() and not blank?(access_token) do
      Enum.find_value(items, fn item ->
        {variable, value} = subject(item)

        with false <- blank?(value),
             {:expired, answer} <- cached(variable, value, access_token) do
          {item, answer}
        else
          _not_expired -> nil
        end
      end)
    end
  end

  # The variable whose probe an item takes, and the name the probe asks about.
  defp subject(:earlier_conference_record),
    do: {"GOOGLE_MEET_CONFERENCE_RECORD", @earlier_conference_record}

  defp subject(variable), do: {variable, System.get_env(variable)}

  # Test files compile in parallel, so the lock keeps a second file from
  # asking while the first waits for Google. The key holds no token.
  defp cached(variable, value, access_token) do
    key = {__MODULE__, variable, value}

    :global.trans({key, self()}, fn ->
      case :persistent_term.get(key, nil) do
        nil ->
          outcome = variable |> probe(value, access_token) |> classify()
          :persistent_term.put(key, outcome)
          outcome

        outcome ->
          outcome
      end
    end)
  end

  # Any include filter can select a live test, and at tag time ExUnit does
  # not know the test's name and describe to evaluate it.
  defp live_run? do
    (ExUnit.configuration()[:include] || []) != []
  end

  defp classify({:ok, %{status: 404, body: %{"error" => %{"status" => "NOT_FOUND"} = error}}}),
    do: {:expired, answer(404, error)}

  defp classify(
         {:ok, %{status: 403, body: %{"error" => %{"status" => "PERMISSION_DENIED"} = error}}}
       ) do
    if is_nil(error_reason(error)) and might_not_exist?(error["message"]),
      do: {:expired, answer(403, error)},
      else: :not_expired
  end

  defp classify(_result), do: :not_expired

  # Status, Google's error status, and the ErrorInfo reason or else the message.
  defp answer(status, error) do
    "#{status} #{error["status"]} " <> (error_reason(error) || inspect(error["message"]))
  end

  defp error_reason(%{"details" => details}) when is_list(details) do
    Enum.find_value(details, fn
      %{"@type" => @error_info, "reason" => reason} when is_binary(reason) -> reason
      _detail -> nil
    end)
  end

  defp error_reason(_error), do: nil

  defp might_not_exist?(message) when is_binary(message), do: message =~ "might not exist"
  defp might_not_exist?(_message), do: false

  defp skip_reason(item, answer, env) do
    reason = "#{expired_data(item)}, has expired: Google answered #{answer}; #{@docs}"
    IO.puts("live_smoke skip #{Path.relative_to_cwd(env.file)}:#{env.line}: #{reason}")
    reason
  end

  defp expired_data(:earlier_conference_record) do
    "#{@earlier_conference_record}, the earlier conference prepared on " <>
      "#{Date.to_iso8601(@prepared_on)} in the space of GOOGLE_MEET_CONFERENCE_RECORD"
  end

  defp expired_data(variable), do: "#{variable}, prepared on #{Date.to_iso8601(@prepared_on)}"

  defp known_item!(item) when item in @items, do: :ok

  defp known_item!(item) do
    raise ArgumentError,
          "#{inspect(item)} is not prepared Meet data that prepared!/1 can check; use " <>
            Enum.map_join(@variables, ", ", &inspect/1) <> " or :earlier_conference_record"
  end

  defp blank?(value), do: value in [nil, ""]
end
