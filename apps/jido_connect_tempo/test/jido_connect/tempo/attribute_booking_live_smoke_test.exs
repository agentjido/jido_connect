defmodule Jido.Connect.Tempo.AttributeBookingLiveSmokeTest do
  @moduledoc """
  Live smoke checks of the worklog create on a site that requires work
  attributes: a booking with the required values through the API token, a
  booking with an unknown account key, and a booking through the OAuth
  write grant.

      MIX_ENV=test TEMPO_WORK_ATTRIBUTES=required TEMPO_LIVE_DESTRUCTIVE=true \\
        mix do --app jido_connect_tempo test --include live_smoke \\
        test/jido_connect/tempo/attribute_booking_live_smoke_test.exs

  The checks need the test attributes of the booking lookup checks in the
  required mode: `_JclPhase_` (STATIC_LIST), `_JclBillable_` (CHECKBOX),
  `_JclHours_` (INPUT_NUMERIC) and `_JclAccount_` (ACCOUNT) required, the
  free-text `_JclNote_` optional. They exist on the shared site only around
  a run, `tempo_attributes.py up` creates them and `down` deletes them; see
  `docs/live_smoke_tests.md`. While they exist, run only this file and the
  booking lookup checks. Each check fails before it writes unless
  `TEMPO_WORK_ATTRIBUTES` is `required` and Tempo lists the four as
  required.

  Every booking carries a value for each of the four, read before the first
  write through the booking lookup actions, which are not recorded: the
  stored value of the label build, `"true"`, `"1.5"` and the key of the
  account `TEMPO_ACCOUNT_ID`. `_JclNote_` stays empty.

  Each run creates three worklogs of the test user on `TEMPO_JIRA_ISSUE_ID`
  on 2026-10-27, in the open October period. They stay on the site; the
  connector has no delete.

  - The estimate seed: one POST through `Transport.post/3`, outside the
    actions and before the recording starts, with
    `remainingEstimateSeconds` 7200, so the issue has a remaining estimate
    that the next booking can change. The create action never sends that
    field.
  - The attribute booking through `prepare/4` and `commit/4` with the API
    token, without start time and without remaining estimate, with a long
    description; read back with `tempo.worklogs.list_own`. Before the seed,
    after it and after this booking the check reads the issue's worklog
    total and remaining estimate from Jira, waiting each time until Jira
    lists the new worklog. On 2026-11-06 Tempo booked the omitted start
    time as 00:00:00, and the booking lowered the remaining estimate from
    7200 to 5400 seconds; the check expects both again.
  - The OAuth booking through `prepare/4` and `commit/4` with the OAuth
    access token, on a connection whose labels are
    `ScopeResolver.granted_labels/1` of the `scope` recorded in
    `oauth_refresh.json`. Before it writes, the check fails unless that
    scope grants `worklogs:manage` and not `write`, and unless
    `TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT` lies within 10 seconds of the
    response's `date` plus its `expires_in`, which shows that this response
    issued the stored token pair. After the booking it waits until Jira
    lists it, so the attribute booking, in whichever order ExUnit runs the
    checks, starts with no worklog of the run still on its way to Jira.

  The booking with an unknown account key must create nothing; if Tempo
  accepts it, the check stops at once and names the new ID. On 2026-11-06
  Tempo answered it with 404 `Account not found`.

  With recording on, the attribute booking records its create and read-back
  as `worklog_create_attributes` and `.2`, the unknown account key its
  answer as `worklog_create_invalid_attribute`, and the OAuth booking its
  create and read-back as `worklog_create_oauth` and `.2`. The seed, the
  Jira reads and the booking lookup reads are not recorded. The read-backs
  pass through `LiveTempo.site_data/2`, which leaves out values of the
  site's other attributes.

  Apart from the checks that stop it before it writes, every provider call
  of a check runs before its first assertion, so a failed assertion never
  needs another booking to learn the rest. A check prints the ID of each
  worklog it created as soon as Tempo returns it, before it waits for Jira,
  and then what it observed; it never prints Tempo's error text or an
  account ID. ExUnit prints the arguments of a failing call, so checks that
  involve a token or the test user's account ID compute a boolean first and
  fail with a fixed message.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  import Jido.Connect.Tempo.TestSupport.LiveTempo,
    only: [
      commit: 4,
      context!: 3,
      error_summary: 1,
      invoke: 4,
      invoke: 5,
      ok!: 2,
      raw_worklogs!: 3,
      request!: 3,
      site_data: 2,
      stop_if_created!: 2
    ]

  alias Jido.Connect.{Error, Scope}
  alias Jido.Connect.Tempo.{Fixture, ScopeResolver}
  alias Jido.Connect.Tempo.Client.Transport

  # The attribute booking waits for Jira twice and the OAuth booking once,
  # each wait up to 29 pauses of 2 s and 30 reads. ExUnit's default of 60 s
  # would end a slow attribute booking in its second wait, after both of
  # its worklogs exist and before its report.
  @moduletag timeout: :timer.minutes(5)

  @recorder {:jido_connect_tempo, :tempo_req_options}
  @jira ["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN"]
  @env [
    "TEMPO_WORK_ATTRIBUTES",
    "TEMPO_API_ORIGIN",
    "TEMPO_JIRA_ISSUE_ID",
    "TEMPO_JIRA_PROJECT_ID",
    "TEMPO_ACCOUNT_ID" | @jira
  ]
  @day "2026-10-27"
  @attribute_keys ["_JclAccount_", "_JclBillable_", "_JclHours_", "_JclNote_", "_JclPhase_"]
  @required ["_JclAccount_", "_JclBillable_", "_JclHours_", "_JclPhase_"]
  @labels ["tempo.worklogs.read", "tempo.worklogs.write", "tempo.accounts.read"]
  @estimate 7200
  @seconds 1800
  @unknown_account "JCL-UNKNOWN"
  @seed_marker "JCL live estimate seed"
  @invalid_marker "JCL live invalid attribute"
  @oauth_marker "JCL live OAuth booking"
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  # More than 700 bytes with umlauts, so the recording shows that Tempo
  # keeps a long description whole.
  @description "JCL live attribute booking. " <>
                 Enum.map_join(
                   1..12,
                   " ",
                   &"Part #{&1}: the description stays whole, with umlauts ä, ö, ü and ß."
                 )

  @tag env!(["TEMPO_API_TOKEN" | @env])
  @tag write!(:tempo)
  test "books the required attributes through prepare and commit and reads them back",
       %{env: env} do
    required!(env)
    token = env["TEMPO_API_TOKEN"]
    context = context!(env, :api_token, @labels)
    account_id = context.connection.subject.account_id
    issue_id = String.to_integer(env["TEMPO_JIRA_ISSUE_ID"])
    attributes = attributes!(env, context, :api_token, token)
    seeder = request!(env, :api_token, token)

    input = %{
      author_account_id: account_id,
      issue_id: issue_id,
      start_date: @day,
      time_spent_seconds: @seconds,
      description: @description,
      attributes: attributes
    }

    initial = jira(env, issue_id, 0)
    seed = post_seed(seeder, seed_body(account_id, issue_id, attributes))
    IO.puts("attribute booking: estimate seed #{seed_summary(seed)}")
    seeded = after_write(seed, env, issue_id, initial, 1)

    LiveSmoke.record(@recorder, :tempo, "worklog_create_attributes",
      accounts: [account_id],
      transform: site_data(%{}, @attribute_keys)
    )

    create = commit(context, :api_token, token, input)
    read = invoke(context, :api_token, token, %{from: @day, to: @day})
    IO.puts("attribute booking: booking #{summary(create)}")

    booked =
      after_write(create, env, issue_id, initial, if(match?({:ok, _}, seed), do: 2, else: 1))

    IO.puts("""
    attribute booking: Jira worklog total and remaining estimate before \
    #{inspect(initial)}, after the seed #{inspect(seeded)}, after the booking \
    #{inspect(booked)}\
    """)

    seed_id =
      case seed do
        {:ok, id} -> id
        other -> flunk("the estimate seed got #{summary(other)}")
      end

    %{worklog: created} = ok!(create, "the attribute booking")

    assert created.tempo_worklog_id > seed_id

    assert {created.start_date, created.time_spent_seconds, created.billable_seconds,
            created.issue_id} == {@day, @seconds, @seconds, issue_id}

    whole? = created.description == @description
    assert whole?, "the booked description is not the one sent"
    own? = created.author_account_id == account_id
    assert own?, "the booked worklog names another author than the connection's account"

    # Tempo returns the values as sent, in an order of its own.
    assert Enum.sort(created.work_attributes) == Enum.sort(attributes)

    # Without a start time Tempo books the start of the day in the worker's
    # time zone, Europe/Berlin (recorded 2026-11-06).
    assert {created.start_time, created.start_date_time_utc} ==
             {"00:00:00", "2026-10-26T23:00:00Z"}

    case Enum.filter(
           ok!(read, "the read-back").worklogs,
           &(&1.tempo_worklog_id == created.tempo_worklog_id)
         ) do
      [readback] ->
        assert Map.drop(readback, [:author_account_id, :updated_at]) ==
                 Map.drop(created, [:author_account_id, :updated_at])

      found ->
        flunk("the read-back of #{@day} holds the booked worklog #{length(found)} times")
    end

    # The seed sets the remaining estimate; the booking without one lowers
    # it by the booked time (recorded 2026-11-06: 7200, then 5400).
    assert {:ok, %{remaining: @estimate}} = seeded
    assert {:ok, %{remaining: remaining}} = booked
    assert remaining == @estimate - @seconds
  end

  @tag env!(["TEMPO_API_TOKEN" | @env])
  @tag write!(:tempo)
  test "an unknown account key in the ACCOUNT attribute is rejected and creates nothing",
       %{env: env} do
    required!(env)
    token = env["TEMPO_API_TOKEN"]
    context = context!(env, :api_token, @labels)
    account_id = context.connection.subject.account_id
    attributes = attributes!(env, context, :api_token, token)

    input = %{
      author_account_id: account_id,
      issue_id: String.to_integer(env["TEMPO_JIRA_ISSUE_ID"]),
      start_date: @day,
      start_time: "11:00:00",
      time_spent_seconds: 600,
      description: @invalid_marker,
      attributes: put_value(attributes, "_JclAccount_", @unknown_account)
    }

    LiveSmoke.record(@recorder, :tempo, "worklog_create_invalid_attribute",
      accounts: [account_id]
    )

    result = commit(context, :api_token, token, input)
    stop_if_created!(result, "the unknown account key")
    day = raw_worklogs!(env, token, %{from: @day, to: @day})

    IO.puts("unknown account key: #{summary(result)}")

    # Tempo answers an unknown account key with 404 `Account not found`
    # (recorded 2026-11-06), which quotes no input.
    assert match?(
             {:error, %Error.ProviderError{reason: :not_found, status: 404, delivery: :rejected}},
             result
           ),
           "the unknown account key got #{summary(result)}"

    {:error, error} = result
    known? = match?(%{details: %{message: "Account not found"}}, error)
    assert known?, "Tempo's 404 names another message than Account not found"
    assert Error.retry_guidance(error) == :do_not_retry

    hidden? =
      not String.contains?(inspect(Error.to_map(error)), [@unknown_account, @invalid_marker])

    assert hidden?, "the rejection names the unknown account key or the description"

    none? = not Enum.any?(day, &(&1["description"] == @invalid_marker))
    assert none?, "a worklog with the unknown account key exists on #{@day}"
  end

  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT" | @env])
  @tag write!(:tempo)
  test "books the required attributes through the OAuth write grant", %{env: env} do
    required!(env)
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    scope = recorded_scope!(env)
    grants = Scope.parse(scope)
    labels = ScopeResolver.granted_labels(scope)

    # The stored pair's grant names worklogs:manage, never the coarse write.
    assert "worklogs:manage" in grants
    refute "write" in grants
    assert "tempo.worklogs.write" in labels

    context = context!(env, :oauth2_user, labels)
    account_id = context.connection.subject.account_id
    issue_id = String.to_integer(env["TEMPO_JIRA_ISSUE_ID"])
    attributes = attributes!(env, context, :oauth2_user, token)

    input = %{
      author_account_id: account_id,
      issue_id: issue_id,
      start_date: @day,
      start_time: "10:30:00",
      time_spent_seconds: 900,
      description: @oauth_marker,
      attributes: attributes
    }

    before = jira(env, issue_id, 0)

    LiveSmoke.record(@recorder, :tempo, "worklog_create_oauth",
      accounts: [account_id],
      transform: site_data(%{}, @attribute_keys)
    )

    create = commit(context, :oauth2_user, token, input)
    read = invoke(context, :oauth2_user, token, %{from: @day, to: @day})
    IO.puts("OAuth booking: #{summary(create)}")

    # The check ends only once Jira lists the booking, so the attribute
    # booking never starts while it is still on its way to Jira.
    synced = after_write(create, env, issue_id, before, 1)

    IO.puts("""
    OAuth booking: Jira worklog total and remaining estimate before \
    #{inspect(before)}, after the booking #{inspect(synced)}\
    """)

    %{worklog: created} = ok!(create, "the OAuth booking")

    assert {created.start_date, created.start_time, created.time_spent_seconds,
            created.billable_seconds, created.issue_id, created.description} ==
             {@day, "10:30:00", 900, 900, issue_id, @oauth_marker}

    own? = created.author_account_id == account_id
    assert own?, "the booked worklog names another author than the connection's account"

    assert Enum.sort(created.work_attributes) == Enum.sort(attributes)

    case Enum.filter(
           ok!(read, "the read-back").worklogs,
           &(&1.tempo_worklog_id == created.tempo_worklog_id)
         ) do
      [readback] ->
        assert Map.drop(readback, [:author_account_id, :updated_at]) ==
                 Map.drop(created, [:author_account_id, :updated_at])

      found ->
        flunk("the read-back of #{@day} holds the booked worklog #{length(found)} times")
    end
  end

  defp required!(env) do
    unless env["TEMPO_WORK_ATTRIBUTES"] == "required",
      do: flunk("these checks need TEMPO_WORK_ATTRIBUTES=required and a required window")
  end

  # The scope recorded in oauth_refresh.json. It names the stored pair's
  # grant only if that refresh issued the pair, so the pair's expiry, which
  # the exchange test writes as TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT from its
  # clock before the request, must lie within 10 seconds of the response's
  # `date` plus its `expires_in`. A pair rotated without recording stops the
  # check here, before a write, instead of at Tempo's 403.
  defp recorded_scope!(env) do
    %{"body" => %{"scope" => scope, "expires_in" => seconds}, "headers" => %{"date" => [date]}} =
      Fixture.recorded!("oauth_refresh")

    with {:ok, expires_at, 0} <- DateTime.from_iso8601(env["TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT"]),
         {:ok, issued} <- http_date(date),
         true <- abs(DateTime.diff(expires_at, DateTime.add(issued, seconds))) <= 10 do
      scope
    else
      _mismatch ->
        flunk(
          "TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT does not match oauth_refresh.json, so the " <>
            "recorded scope is not the stored pair's; record the exchange of the next pair"
        )
    end
  end

  # An HTTP date such as `Mon, 02 Nov 2026 14:26:19 GMT`.
  defp http_date(text) do
    with [_text, day, month, year, time] <-
           Regex.run(~r/^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}:\d{2}:\d{2}) GMT$/, text),
         index when is_integer(index) <- Enum.find_index(@months, &(&1 == month)),
         {:ok, date} <- Date.new(String.to_integer(year), index + 1, String.to_integer(day)),
         {:ok, time} <- Time.from_iso8601(time) do
      DateTime.new(date, time)
    end
  end

  # The four required values, read through the booking lookup actions with
  # the check's own profile, before any write and before the recording
  # starts. Fails unless Tempo lists the four test attributes as required.
  defp attributes!(env, context, profile, token) do
    project = String.to_integer(env["TEMPO_JIRA_PROJECT_ID"])

    listed =
      ok!(invoke(context, profile, token, %{}, "tempo.work_attribute.list"), "the attribute read")

    accounts =
      ok!(
        invoke(context, profile, token, %{project_id: project}, "tempo.account.list_for_project"),
        "the account read"
      )

    by_key = Map.new(listed.attributes, &{&1.key, &1})

    unless Enum.all?(@required, &match?(%{required: true}, by_key[&1])),
      do:
        flunk("Tempo does not list the four test attributes as required; open a required window")

    build =
      Enum.find(by_key["_JclPhase_"].values || [], &(&1.label == "build")) ||
        flunk("_JclPhase_ has no stored value labelled build")

    account =
      Enum.find(accounts.accounts, &(Integer.to_string(&1.id) == env["TEMPO_ACCOUNT_ID"])) ||
        flunk("TEMPO_ACCOUNT_ID is not an account candidate of TEMPO_JIRA_PROJECT_ID")

    [
      %{key: "_JclAccount_", value: account.key},
      %{key: "_JclPhase_", value: build.value},
      %{key: "_JclBillable_", value: "true"},
      %{key: "_JclHours_", value: "1.5"}
    ]
  end

  defp put_value(attributes, key, value) do
    Enum.map(attributes, &if(&1.key == key, do: %{&1 | value: value}, else: &1))
  end

  # The body of the estimate seed: the booking day, the required values and
  # a remaining estimate, which the create action never sends.
  defp seed_body(account_id, issue_id, attributes) do
    %{
      "authorAccountId" => account_id,
      "issueId" => issue_id,
      "startDate" => @day,
      "startTime" => "07:00:00",
      "timeSpentSeconds" => 60,
      "description" => @seed_marker,
      "remainingEstimateSeconds" => @estimate,
      "attributes" => Enum.map(attributes, &%{"key" => &1.key, "value" => &1.value})
    }
  end

  # One POST /4/worklogs through the client transport, which sends it once
  # and reports a timeout as :sent_outcome_unknown. The check sends it
  # before LiveSmoke.record/4, so the recorder is not yet the adapter.
  # Returns the new ID or the error, never the body, which names the
  # account ID.
  defp post_seed(request, body) do
    case Transport.post(request, "/4/worklogs", json: body) do
      {:ok, %{"tempoWorklogId" => id}} when is_integer(id) -> {:ok, id}
      {:ok, _body} -> :no_worklog_id
      {:error, _error} = error -> error
    end
  end

  # After a write that succeeded, Jira's state once it lists `added` more
  # worklogs than `initial`; nil after a failed write or read.
  defp after_write({:ok, _created}, env, issue_id, {:ok, %{total: total}}, added),
    do: jira(env, issue_id, total + added)

  defp after_write(_result, _env, _issue_id, _initial, _added), do: nil

  # The issue's worklog total and remaining estimate, read directly from
  # Jira, outside the package and the recorder, once the total has reached
  # `total`. Tempo hands its worklogs to Jira, so this asks at most 30 times,
  # 2 seconds apart. Returns :timeout or :error instead of failing, since it
  # runs before the assertions.
  defp jira(env, issue_id, total, attempts \\ 30) do
    case jira_get(env, "/rest/api/3/issue/#{issue_id}/worklog", maxResults: 1) do
      {:ok, %{"total" => count}} when is_integer(count) and count >= total ->
        remaining(env, issue_id, count)

      {:ok, %{"total" => count}} when is_integer(count) and attempts > 1 ->
        Process.sleep(2000)
        jira(env, issue_id, total, attempts - 1)

      {:ok, %{"total" => count}} when is_integer(count) ->
        :timeout

      _other ->
        :error
    end
  end

  defp remaining(env, issue_id, total) do
    case jira_get(env, "/rest/api/3/issue/#{issue_id}", fields: "timetracking") do
      {:ok, %{"fields" => %{"timetracking" => tracking}}} when is_map(tracking) ->
        {:ok, %{total: total, remaining: tracking["remainingEstimateSeconds"]}}

      _other ->
        :error
    end
  end

  defp jira_get(env, path, params) do
    case Req.get(env["JIRA_SITE"] <> path,
           auth: {:basic, "#{env["JIRA_EMAIL"]}:#{env["JIRA_API_TOKEN"]}"},
           params: params,
           retry: false
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      _other -> :error
    end
  end

  defp seed_summary({:ok, id}), do: "worklog #{id}"
  defp seed_summary(result), do: summary(result)

  # The Tempo ID, booking day, start time, UTC start and seconds of a
  # booking, or the reason, status and delivery of its error.
  defp summary({:ok, %{worklog: worklog}}) do
    "worklog #{worklog.tempo_worklog_id} on #{worklog.start_date}, start time " <>
      "#{inspect(worklog.start_time)}, UTC start #{inspect(Map.get(worklog, :start_date_time_utc))}, " <>
      "#{worklog.time_spent_seconds} s, billable #{inspect(Map.get(worklog, :billable_seconds))}, " <>
      "#{length(worklog.work_attributes)} attribute values"
  end

  defp summary({:error, %Error.ProviderError{} = error} = result),
    do: "#{error_summary(result)}, delivery #{inspect(error.delivery)}"

  defp summary(result), do: error_summary(result)
end
