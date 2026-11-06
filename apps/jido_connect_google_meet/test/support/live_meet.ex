defmodule Jido.Connect.Google.Meet.TestSupport.LiveMeet do
  @moduledoc false

  # The Meet live tests read meeting data prepared on 2026-10-30. Google
  # deletes a conference record, and the transcript entries under it, 30 days
  # after the conference ended, so from 2026-11-29 on a live run would fail on
  # missing data. A live test that reads that data adds a `prepared!/1` tag
  # after its `env!/1` tag:
  #
  #     @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  #     @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])
  #
  # It returns `[live_meet_prepared: variables]` and adds `skip:` when Google
  # no longer serves the data of a variable. It tells that from Google's
  # answer, not from a date. In a run that can include the test, through
  # `--only live_smoke`, `--include live_smoke` or a location in the test's
  # file, it asks Google while the test file compiles, with
  # `GOOGLE_ACCESS_TOKEN`: `conferenceRecords.get` with `fields=name` for
  # `GOOGLE_MEET_CONFERENCE_RECORD`, and one transcript entry name for
  # `GOOGLE_MEET_TRANSCRIPT`. Without the token or the variable it asks
  # nothing, and `env!/1` skips the test. Other variables raise when the file
  # compiles.
  #
  # Two answers skip: 404 `NOT_FOUND`, Google's answer for a missing
  # transcript, and 403 `PERMISSION_DENIED` without an ErrorInfo reason whose
  # message says the resource might not exist, Google's answer for a
  # conference record that does not exist. Google gives the same answers for a
  # well-formed ID that never named data the test user can see, so a wrong ID
  # of that kind is skipped as expired too. Every other answer leaves the test
  # to run, so it fails on 401, a 403 with `ACCESS_TOKEN_SCOPE_INSUFFICIENT`,
  # 400 for an ID Google cannot parse, 5xx and transport errors.

  alias Jido.Connect.Google.Meet.Client.Transport

  @prepared_on "2026-10-30"
  @variables ["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"]
  @error_info "type.googleapis.com/google.rpc.ErrorInfo"

  defmacro prepared!(variables) do
    quote do
      Jido.Connect.Google.Meet.TestSupport.LiveMeet.prepared_tags(unquote(variables), __ENV__)
    end
  end

  @doc false
  def prepared_tags(variables, %Macro.Env{} = env) when is_list(variables) do
    Enum.each(variables, &known_variable!/1)
    tags = [live_meet_prepared: variables]
    token = System.get_env("GOOGLE_ACCESS_TOKEN")

    with true <- live_run?(env) and not blank?(token),
         reason when is_binary(reason) <- Enum.find_value(variables, &expired(&1, token)) do
      IO.puts("live_smoke skip #{Path.relative_to_cwd(env.file)}:#{env.line}: #{reason}")
      Keyword.put(tags, :skip, reason)
    else
      _runnable -> tags
    end
  end

  defp expired(variable, token) do
    value = System.get_env(variable)

    with false <- blank?(value),
         answer when is_binary(answer) <- variable |> probe(value, token) |> deleted() do
      "#{variable}, prepared on #{@prepared_on}, has expired: Google answered #{answer}; " <>
        "see docs/live_smoke_tests.md"
    else
      _served_or_other -> nil
    end
  end

  defp probe("GOOGLE_MEET_CONFERENCE_RECORD", record, token),
    do: get(token, "/v2/" <> encode(record), fields: "name")

  # One entry name, without its text.
  defp probe("GOOGLE_MEET_TRANSCRIPT", transcript, token) do
    get(token, "/v2/" <> encode(transcript) <> "/entries",
      pageSize: 1,
      fields: "transcriptEntries(name)"
    )
  end

  defp get(token, path, params) do
    token
    |> Transport.request()
    |> Req.get(url: path, params: params)
  end

  defp encode(name) do
    name
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode(&1, fn char -> URI.char_unreserved?(char) end))
  end

  # The status, Google's error status, and the ErrorInfo reason or else the
  # message, for the two answers that mean the data is gone.
  defp deleted({:ok, %{status: 404, body: %{"error" => %{"status" => "NOT_FOUND"} = error}}}),
    do: answer(404, error)

  defp deleted(
         {:ok, %{status: 403, body: %{"error" => %{"status" => "PERMISSION_DENIED"} = error}}}
       ) do
    if is_nil(error_reason(error)) and might_not_exist?(error["message"]),
      do: answer(403, error)
  end

  defp deleted(_result), do: nil

  defp answer(status, error),
    do: "#{status} #{error["status"]} " <> (error_reason(error) || inspect(error["message"]))

  defp error_reason(%{"details" => details}) when is_list(details) do
    Enum.find_value(details, fn
      %{"@type" => @error_info, "reason" => reason} when is_binary(reason) -> reason
      _detail -> nil
    end)
  end

  defp error_reason(_error), do: nil

  defp might_not_exist?(message), do: is_binary(message) and message =~ "might not exist"

  # `--only live_smoke` and `--include live_smoke` include the tag;
  # `mix test <file>:<line>` includes a location.
  defp live_run?(env) do
    include = ExUnit.configuration()[:include] || []

    Enum.any?(include, fn
      :live_smoke -> true
      {:live_smoke, _value} -> true
      {:location, {path, _lines}} -> String.ends_with?(env.file, path)
      {:location, path} when is_binary(path) -> String.ends_with?(env.file, path)
      _filter -> false
    end)
  end

  defp known_variable!(variable) when variable in @variables, do: :ok

  defp known_variable!(variable) do
    raise ArgumentError,
          "#{inspect(variable)} is no prepared Meet data that prepared!/1 can check; " <>
            "use #{Enum.join(@variables, " or ")}"
  end

  defp blank?(value), do: value in [nil, ""]
end
