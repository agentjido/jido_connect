defmodule Jido.Connect.Tempo.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Tempo test account of the Atlassian test site.

      MIX_ENV=test mix do --app jido_connect_tempo test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  The Atlassian account ID of the test user comes from Jira
  `GET /rest/api/3/myself`; that helper call is not recorded. Neither are
  the direct Tempo reads that the own worklog and period checks compare
  against.

  The own worklog checks are the five tests that record `worklogs_own`,
  `worklogs_own_small_page`, `worklogs_own_day`, `worklogs_own_empty` and
  `worklogs_own_jira`. They hold on the test user's seeded worklogs on
  `TEMPO_JIRA_ISSUE_ID` alone: one on the first and one on the last day of
  each period (August 1 and 31, September 1 and 30, October 1 and 30); five
  on October 1, among them two that differ only in their IDs and one with
  zero billable seconds; and fillers across October, among them one on
  October 28 and one on October 30. The test user has no worklog in July
  2026. Each read except the empty July range compares every worklog with
  a direct Tempo read and counts only minimums, so further own worklogs
  from August to October do not break the checks; the July read must
  return no worklogs.

  Three recordings also hold worklogs that the seeded data lacks. The test
  user created them on JCL-2 on 2026-11-02: 79166, booked at 00:30
  Europe/Berlin on October 31, so its UTC date is October 30, with a
  description of 778 bytes, in `worklogs_own.2.json` and
  `worklogs_own_day.json`; and 79167 and 79168 on October 28, created
  through Jira's worklog API without a comment and with an empty one, in
  `worklogs_own_jira.json`. Re-recording these files needs those worklogs,
  since the offline tests pin their IDs and shapes.

  The period checks hold on the test user's seeded approvals alone: August
  2026 APPROVED, September IN_REVIEW and October OPEN. Each status and its
  time are compared with a direct approval read of the same period by the
  same user.

  Two tests write and run only with `TEMPO_LIVE_DESTRUCTIVE=true`. The
  worklog create creates one worklog of the test user on 2026-10-29 per run,
  which stays on the site, and books the same input into the approved August
  period, which Tempo rejects. The invalid start time test posts one booking
  into the approved August period that Tempo cannot accept. Neither depends
  on worklogs outside the seed except the one the create just made.

  ExUnit prints the arguments of a failing call, so checks that involve a real
  token or the test user's account ID compute a boolean first and fail with
  a fixed message.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  import Jido.Connect.Tempo.TestSupport.LiveTempo,
    only: [
      account_id!: 1,
      context!: 2,
      context!: 3,
      invoke: 4,
      invoke: 5,
      ok!: 2,
      raw_worklogs!: 3,
      request!: 3,
      request!: 4
    ]

  alias Jido.Connect.{Context, CredentialLease, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Client.{Pagination, Transport}
  alias Jido.Connect.Tempo.{Client, OAuth, ScopeResolver}

  @recorder {:jido_connect_tempo, :tempo_req_options}
  @oauth_recorder {:jido_connect_tempo, :tempo_oauth_req_options}
  @create "tempo.worklog.create"
  @create_marker "JCL live create test"
  @oauth ["TEMPO_OAUTH_CLIENT_ID", "TEMPO_OAUTH_CLIENT_SECRET", "TEMPO_OAUTH_REDIRECT_URI"]
  @october [params: [from: "2026-10-01", to: "2026-10-31"]]
  @jira ["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN"]
  @boundary_days [
    "2026-08-01",
    "2026-08-31",
    "2026-09-01",
    "2026-09-30",
    "2026-10-01",
    "2026-10-30"
  ]
  # This file lies in apps/jido_connect_tempo/test/jido_connect/tempo.
  @repository Path.expand("../../../../..", __DIR__)

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads periods with the API token", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "periods")

    assert {:ok, %{"periods" => [_ | _]}} = Transport.get(request, "/4/periods", @october)
  end

  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads periods with the OAuth access token", %{env: env} do
    request = request!(env, :oauth2_user, env["TEMPO_OAUTH_ACCESS_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "periods_oauth")

    assert {:ok, %{"periods" => [_ | _]}} = Transport.get(request, "/4/periods", @october)
  end

  @tag env!(["TEMPO_API_ORIGIN" | @jira])
  test "an invalid token gets a normalized auth error without the token", %{env: env} do
    token = "jido-connect-invalid-tempo-token"
    request = request!(env, :api_token, token)
    LiveSmoke.record(@recorder, :tempo, "unauthorized")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :unauthorized, status: 401} = error} =
             Transport.get(request, "/4/periods", @october)

    refute_leak(error, token)
  end

  @tag env!(["TEMPO_API_TOKEN" | @jira])
  test "a token sent to another cluster gets an auth error", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    request = request!(env, :api_token, token, "https://api.eu.tempo.io")
    LiveSmoke.record(@recorder, :tempo, "wrong_cluster")

    assert {:error, %Error.ProviderError{reason: :unauthorized, status: 401} = error} =
             Transport.get(request, "/4/periods", @october)

    refute_leak(error, token)
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an unknown worklog gets a not-found error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "not_found")

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404, details: details}} =
             Transport.get(request, "/4/worklogs/999999999")

    assert details.message == "Worklog cannot be found"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an unknown route gets a not-found error with a non-JSON body", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "not_found_html")

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404}} =
             Transport.get(request, "/4/global-configurations")
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an invalid date gets a bad-request error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "bad_request")

    assert {:error, %Error.ProviderError{reason: :bad_request, status: 400, details: details}} =
             Transport.get(request, "/4/periods", params: [from: "not-a-date", to: "2026-10-31"])

    assert details.message =~ "not-a-date"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "a read the test user may not do gets a forbidden error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "forbidden")

    assert {:error, %Error.ProviderError{reason: :forbidden, status: 403}} =
             Transport.get(request, "/4/holiday-schemes")
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "pages through the October worklogs of the test user", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    path = "/4/worklogs/user/" <> URI.encode(request.account_id, &URI.char_unreserved?/1)
    LiveSmoke.record(@recorder, :tempo, "worklogs_page")

    assert {:ok, worklogs} = Pagination.collect(request, path, @october)

    count = length(worklogs)
    assert count > 50, "expected more than one page of 50 worklogs, got #{count}"
    own? = Enum.all?(worklogs, &(get_in(&1, ["author", "accountId"]) == request.account_id))
    assert own?, "every worklog belongs to the test user"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "lists the own worklogs of the three seeded periods through the action", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    context = context!(env, :api_token)
    range = %{from: "2026-08-01", to: "2026-10-31"}
    LiveSmoke.record(@recorder, :tempo, "worklogs_own")

    result = ok!(invoke(context, :api_token, token, range), "the own worklog read")
    worklogs = result.worklogs

    complete? = result.from == range.from and result.to == range.to and result.complete == true
    assert complete?, "the read did not return its range with complete: true"

    own? = result.account_id == context.connection.subject.account_id
    assert own?, "account_id is not the connection's subject.account_id"

    assert length(worklogs) > 50, "expected more than one page of 50, got #{length(worklogs)}"
    assert Enum.map(worklogs, &key/1) == Enum.map(raw_worklogs!(env, token, range), &raw_key/1)

    days = worklogs |> Enum.map(& &1.start_date) |> MapSet.new()
    assert Enum.reject(@boundary_days, &(&1 in days)) == []

    assert Enum.any?(worklogs, &(&1[:billable_seconds] == 0)), "no zero billable seconds"

    assert Enum.any?(worklogs, &(rem(&1.time_spent_seconds, 3600) != 0)),
           "no duration that is not a whole hour"

    assert twins?(worklogs), "no two worklogs that differ only in their Tempo IDs"
  end

  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads October 1 in pages of two with the OAuth access token", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    request = request!(env, :oauth2_user, token)
    range = %{from: "2026-10-01", to: "2026-10-01"}
    LiveSmoke.record(@recorder, :tempo, "worklogs_own_small_page")

    worklogs =
      ok!(
        Client.list_own_worklogs(request, from: range.from, to: range.to, limit: 2),
        "the small page read"
      )

    assert length(worklogs) > 4, "expected three pages of two, got #{length(worklogs)} worklogs"

    assert Enum.map(worklogs, &key(Tempo.Worklog.to_map(&1))) ==
             Enum.map(raw_worklogs!(env, token, range), &raw_key/1)

    assert twins?(Enum.map(worklogs, &Tempo.Worklog.to_map/1)),
           "no two worklogs that differ only in their Tempo IDs"
  end

  # Tempo filters by the booking day in the worker's time zone, not by the
  # UTC date of the start. The seeded data has no worklog on October 31; the
  # recording holds 79166. An empty answer names the account only in links,
  # so the sanitizer cannot learn the account ID from it, and a recording
  # of an empty October 31 would keep the raw ID. Recording mode therefore
  # stops before the read when Tempo has no worklog on that day.
  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "a one-day range holds the worklogs of that booking day", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    context = context!(env, :oauth2_user)
    range = %{from: "2026-10-31", to: "2026-10-31"}
    raw = raw_worklogs!(env, token, range)

    if LiveSmoke.recording?() and raw == [],
      do: flunk("re-recording worklogs_own_day needs worklog 79166 on 2026-10-31")

    LiveSmoke.record(@recorder, :tempo, "worklogs_own_day")

    day = ok!(invoke(context, :oauth2_user, token, range), "the one-day read")

    assert day.complete == true, "the one-day read did not return complete: true"
    assert Enum.map(day.worklogs, &key/1) == Enum.map(raw, &raw_key/1)

    on_day? = Enum.all?(day.worklogs, &(&1.start_date == "2026-10-31"))
    assert on_day?, "a worklog of the one-day read has another booking day"
  end

  # The empty range is read second in the same recording: its response names
  # the account only in links, so the sanitizer must have learned the
  # account ID from the seeded October 30 first.
  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an empty range returns no worklogs", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    context = context!(env, :oauth2_user)
    seeded = %{from: "2026-10-30", to: "2026-10-30"}
    july = %{from: "2026-07-01", to: "2026-07-31"}
    LiveSmoke.record(@recorder, :tempo, "worklogs_own_empty")

    day = ok!(invoke(context, :oauth2_user, token, seeded), "the October 30 read")

    assert day.worklogs != [], "no worklog on 2026-10-30"

    assert Enum.map(day.worklogs, &key/1) ==
             Enum.map(raw_worklogs!(env, token, seeded), &raw_key/1)

    empty = ok!(invoke(context, :oauth2_user, token, july), "the empty range read")

    none? =
      empty.worklogs == [] and empty.complete == true and empty.from == july.from and
        empty.to == july.to

    assert none?, "the July read did not return worklogs: [] with complete: true"
  end

  # Tempo answers a worklog created through Tempo without a description with
  # its default text, but one created in Jira without a comment or with an
  # empty comment with an empty description. The recording holds two such
  # worklogs, 79167 and 79168; the seeded data has filler 79128 on this day.
  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "keeps the descriptions of October 28 as Tempo sends them", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    context = context!(env, :api_token)
    range = %{from: "2026-10-28", to: "2026-10-28"}
    LiveSmoke.record(@recorder, :tempo, "worklogs_own_jira")

    result = ok!(invoke(context, :api_token, token, range), "the October 28 read")

    assert result.worklogs != [], "no worklog on 2026-10-28"

    assert Enum.map(result.worklogs, &key/1) ==
             Enum.map(raw_worklogs!(env, token, range), &raw_key/1)
  end

  # Tempo reads an approval only for the exact boundaries of one period and
  # answers a range across periods with a 400. The open October period is
  # read first, so the sanitizer learns the account ID from its `user`
  # before it writes the path of the 400, whose body names no account.
  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads the open October approval and rejects a range across periods", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    request = request!(env, :oauth2_user, token)
    LiveSmoke.record(@recorder, :tempo, "timesheet_approval")

    approval =
      ok!(
        Client.get_timesheet_approval(request, "2026-10-01", "2026-10-31"),
        "the October approval read"
      )

    raw = raw_approval!(env, token, %{from: "2026-10-01", to: "2026-10-31"})

    assert approval.status == "OPEN"
    assert {approval.status, approval.updated_at} == raw_evidence(raw)
    assert {approval.period_from, approval.period_to} == {"2026-10-01", "2026-10-31"}

    own? = approval.user_account_id == request.account_id
    assert own?, "the approval names another user than the connection's account"

    across = Client.get_timesheet_approval(request, "2026-08-01", "2026-09-30")

    rejected? =
      match?({:error, %Error.ProviderError{reason: :bad_request, status: 400}}, across) and
        error_message(across) =~ "not a valid period"

    assert rejected?, "a range across two periods did not get Tempo's 400"
  end

  # The seeded approvals of the test user: August 2026 APPROVED, September
  # IN_REVIEW, October OPEN. Further worklogs in the open October period do
  # not change them. The range starts and ends inside a period, so the first
  # and the last segment are part of a full period. Each segment's evidence
  # is compared with a direct read of the same period by the same user.
  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "the period bookability of the seeded periods matches the user's Tempo view", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    scopes = ["tempo.periods.read", "tempo.approvals.read"]
    context = context!(env, :api_token, scopes)
    range = %{from: "2026-08-15", to: "2026-10-15"}
    LiveSmoke.record(@recorder, :tempo, "period_bookability")

    before = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      ok!(
        invoke(context, :api_token, token, range, "tempo.period.bookability.get"),
        "the period bookability read"
      )

    later = DateTime.utc_now()

    complete? = result.from == range.from and result.to == range.to and result.complete == true
    assert complete?, "the read did not return its range with complete: true"

    own? = result.account_id == context.connection.subject.account_id
    assert own?, "account_id is not the connection's subject.account_id"

    {:ok, checked_at, 0} = DateTime.from_iso8601(result.checked_at)

    assert DateTime.compare(checked_at, before) != :lt and
             DateTime.compare(checked_at, later) != :gt

    segments = result.segments

    assert Enum.map(segments, &{&1.from, &1.to, &1.period_from, &1.period_to}) == [
             {"2026-08-15", "2026-08-31", "2026-08-01", "2026-08-31"},
             {"2026-09-01", "2026-09-30", "2026-09-01", "2026-09-30"},
             {"2026-10-01", "2026-10-15", "2026-10-01", "2026-10-31"}
           ]

    assert Enum.map(segments, & &1.approval_status) == ["APPROVED", "IN_REVIEW", "OPEN"]
    assert Enum.map(segments, & &1.approval_error) == [nil, nil, nil]

    for segment <- segments do
      raw = raw_approval!(env, token, %{from: segment.period_from, to: segment.period_to})
      assert {segment.approval_status, segment.approval_updated_at} == raw_evidence(raw)
    end

    assert Enum.map(segments, &{&1.closure_evidence, &1.state}) == [
             {:unknown, :blocked},
             {:unknown, :blocked},
             {:unknown, :unknown}
           ]

    assert result.state == :blocked

    text = inspect(result)
    clean? = not String.contains?(text, ["comment", "reviewer", "actor", "submit", "recall"])
    assert clean?, "the result holds an approval comment, a reviewer, an actor or an action"
  end

  # The one live write. It creates one worklog of the test user on
  # TEMPO_JIRA_ISSUE_ID on 2026-10-29, in the open October period, through
  # prepare/4 and commit/4 with direct calls denied. The worklog stays on the
  # site; the connector has no delete. The test reads it back with
  # tempo.worklogs.list_own and then books the same input on 2026-08-14, in
  # the approved August period, without bypass. Tempo rejects that booking
  # with a 403 (recorded 2026-11-02); if it accepts it, the test stops at
  # once with the new ID. Every provider call runs before the first
  # assertion, so a failed check never needs a second create to learn the
  # rest.
  #
  # The three responses go into one recording, so the sanitizer learns the
  # account ID from the created worklog's author before it writes the path of
  # the read.
  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN", "TEMPO_JIRA_ISSUE_ID" | @jira])
  @tag write!(:tempo)
  test "creates one own worklog in the open period, reads it back and sees the approved period reject a booking",
       %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    context = context!(env, :api_token, ["tempo.worklogs.read", "tempo.worklogs.write"])
    account_id = context.connection.subject.account_id
    issue_id = String.to_integer(env["TEMPO_JIRA_ISSUE_ID"])
    day = %{from: "2026-10-29", to: "2026-10-29"}

    input = %{
      author_account_id: account_id,
      issue_id: issue_id,
      start_date: "2026-10-29",
      start_time: "08:15:00",
      time_spent_seconds: 3661,
      description: @create_marker
    }

    LiveSmoke.record(@recorder, :tempo, "worklog_create")

    create = commit(context, :api_token, token, input)
    read = invoke(context, :api_token, token, day)
    approved = commit(context, :api_token, token, %{input | start_date: "2026-08-14"})

    stop_if_created!(approved, "the approved August period")

    %{worklog: created} = ok!(create, "the worklog create")

    assert is_integer(created.tempo_worklog_id) and created.tempo_worklog_id > 0

    assert {created.start_date, created.start_time, created.time_spent_seconds, created.issue_id,
            created.description} ==
             {"2026-10-29", "08:15:00", 3661, issue_id, @create_marker}

    own? = created.author_account_id == account_id
    assert own?, "the created worklog names another author than the connection's account"

    case Enum.filter(
           ok!(read, "the read-back").worklogs,
           &(&1.tempo_worklog_id == created.tempo_worklog_id)
         ) do
      [readback] ->
        assert {readback.tempo_worklog_id, readback.start_date, readback.time_spent_seconds} ==
                 {created.tempo_worklog_id, "2026-10-29", 3661}

        assert key(readback) == key(created)

      found ->
        flunk("the read-back of 2026-10-29 holds the created worklog #{length(found)} times")
    end

    assert match?(
             {:error,
              %Error.ProviderError{reason: :period_locked, status: 403, delivery: :rejected}},
             approved
           ),
           "the approved-period booking got #{error_summary(approved)}"

    {:error, rejection} = approved
    assert Error.retry_guidance(rejection) == :do_not_retry
    clean? = not String.contains?(inspect(Error.to_map(rejection)), @create_marker)
    assert clean?, "the rejection holds the description"
  end

  # One hand-built POST that the connector itself refuses before sending: a
  # start time of 25:00:00, booked in the approved August period without
  # bypass. Tempo cannot create a worklog from it, but the test posts to the
  # write endpoint with a valid token, so it carries the write gate.
  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN", "TEMPO_JIRA_ISSUE_ID" | @jira])
  @tag write!(:tempo)
  test "a booking with an invalid start time gets a 400 that is not a period lock", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    request = request!(env, :api_token, token)
    LiveSmoke.record(@recorder, :tempo, "worklog_create_invalid_time")

    result =
      Transport.post(request, "/4/worklogs",
        json: %{
          "authorAccountId" => request.account_id,
          "issueId" => String.to_integer(env["TEMPO_JIRA_ISSUE_ID"]),
          "startDate" => "2026-08-14",
          "startTime" => "25:00:00",
          "timeSpentSeconds" => 3661,
          "description" => @create_marker
        }
      )

    stop_if_created!(result, "the invalid start time")

    assert match?(
             {:error, %Error.ProviderError{reason: :bad_request, status: 400}},
             result
           ),
           "the invalid start time got #{error_summary(result)}"
  end

  # A POST with an invented token cannot create a worklog, so this test needs
  # no write gate.
  @tag env!(["TEMPO_API_ORIGIN", "TEMPO_JIRA_ISSUE_ID" | @jira])
  test "a worklog create with an invalid token gets a normalized auth error", %{env: env} do
    token = "jido-connect-invalid-tempo-token"
    request = request!(env, :api_token, token)
    LiveSmoke.record(@recorder, :tempo, "worklog_create_unauthorized")

    result =
      Client.create_worklog(request, %{
        author_account_id: request.account_id,
        issue_id: String.to_integer(env["TEMPO_JIRA_ISSUE_ID"]),
        start_date: "2026-10-29",
        time_spent_seconds: 3661,
        description: @create_marker
      })

    assert {:error,
            %Error.ProviderError{reason: :unauthorized, status: 401, delivery: :rejected} = error} =
             result

    refute_leak(error, token)
    clean? = not String.contains?(inspect(Error.to_map(error)), @create_marker)
    assert clean?, "the auth error holds the description"
  end

  # The token endpoint's rejections are recorded with an invented code and an
  # invented refresh token. A successful exchange needs the code of one
  # browser authorization and every refresh replaces both tokens, so that
  # test runs only with TEMPO_OAUTH_CODE and never uses the stored refresh
  # token.
  @tag env!(@oauth)
  test "the token endpoint rejects an invented authorization code", %{env: env} do
    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_invalid_code")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :forbidden, status: 403} = error} =
             OAuth.exchange_code("jido-connect-invented-code", oauth_opts(env))

    refute_leak(error, env["TEMPO_OAUTH_CLIENT_SECRET"])
  end

  @tag env!(@oauth)
  test "the token endpoint rejects an invented refresh token", %{env: env} do
    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_invalid_refresh_token")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :forbidden, status: 403} = error} =
             OAuth.refresh("jido-connect-invented-refresh-token", oauth_opts(env))

    refute_leak(error, env["TEMPO_OAUTH_CLIENT_SECRET"])
  end

  # Consumes the code and rotates the new pair once. Each pair is written to
  # TEMPO_OAUTH_TOKEN_FILE before anything else can fail: the code is spent
  # after the exchange, and the exchanged pair is invalid after the refresh.
  @tag env!(["TEMPO_OAUTH_CODE", "TEMPO_OAUTH_TOKEN_FILE", "TEMPO_API_ORIGIN"] ++ @oauth ++ @jira)
  test "exchanges a code and refreshes the new pair once", %{env: env} do
    code = env["TEMPO_OAUTH_CODE"]
    file = env["TEMPO_OAUTH_TOKEN_FILE"]
    prepare_token_file!(file)

    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_exchange")
    issued_at = DateTime.utc_now()
    exchanged = token!(OAuth.exchange_code(code, oauth_opts(env)), "code exchange")
    write_token_file!(file, exchanged, issued_at)
    refute_recorded_secrets!("oauth_exchange", [code | token_values(exchanged)])

    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_refresh")
    issued_at = DateTime.utc_now()
    refreshed = token!(OAuth.refresh(refresh_token(exchanged), oauth_opts(env)), "refresh")
    write_token_file!(file, refreshed, issued_at)

    refute_recorded_secrets!(
      "oauth_refresh",
      [code | token_values(exchanged) ++ token_values(refreshed)]
    )

    assert usable_token?(exchanged), "the exchanged token lacks expiry, scope or worklog read"
    assert usable_token?(refreshed), "the refreshed token lacks expiry, scope or worklog read"
    assert rotated?(exchanged, refreshed), "the refresh returned a token of the exchanged pair"

    read =
      env
      |> request!(:oauth2_user, access_token(refreshed))
      |> Transport.get("/4/periods", @october)

    assert match?({:ok, %{"periods" => [_ | _]}}, read),
           "the refreshed access token did not read /4/periods"

    stale =
      env
      |> request!(:oauth2_user, access_token(exchanged))
      |> Transport.get("/4/periods", @october)

    assert match?({:error, %Error.ProviderError{reason: :unauthorized, status: 401}}, stale),
           "the exchanged access token did not get a 401 after the refresh"
  end

  # The helpers below take token maps. Each has a clause for any argument, so
  # no FunctionClauseError prints a token.

  defp token!({:ok, %{access_token: _, refresh_token: _} = token}, _step), do: token

  defp token!({:error, %Error.ProviderError{} = error}, step),
    do: flunk("the #{step} failed: #{inspect(error.reason)}, status #{inspect(error.status)}")

  defp token!(_result, step), do: flunk("the #{step} returned an unexpected result")

  defp access_token(%{access_token: token}), do: token
  defp access_token(_token), do: flunk("no access token")

  defp refresh_token(%{refresh_token: token}), do: token
  defp refresh_token(_token), do: flunk("no refresh token")

  defp token_values(%{access_token: access, refresh_token: refresh}), do: [access, refresh]
  defp token_values(_token), do: flunk("no token pair")

  defp usable_token?(%{expires_in: expires_in, scope: [_ | _] = scope})
       when is_integer(expires_in) and expires_in > 0,
       do: "tempo.worklogs.read" in ScopeResolver.granted_labels(scope)

  defp usable_token?(_token), do: false

  defp rotated?(%{access_token: a1, refresh_token: r1}, %{access_token: a2, refresh_token: r2}),
    do: a1 != a2 and r1 != r2

  defp rotated?(_exchanged, _refreshed), do: false

  # The file must be an absolute path outside the repository, so no commit can
  # pick up the pair; Mix runs the test in the app directory, where a relative
  # path would land. It must be new or empty, so a run cannot overwrite an env
  # file. It is created with mode 0600 at once, which also shows that its
  # directory is writable before the code is spent.
  defp prepare_token_file!(file) do
    unless outside_repository?(file),
      do: flunk("TEMPO_OAUTH_TOKEN_FILE must be an absolute path outside the repository")

    case File.read(file) do
      {:ok, ""} -> :ok
      {:error, :enoent} -> :ok
      _other -> flunk("TEMPO_OAUTH_TOKEN_FILE must name a missing or empty file")
    end

    File.write!(file, "")
    File.chmod!(file, 0o600)
  end

  defp outside_repository?(file) do
    Path.type(file) == :absolute and
      not String.starts_with?(Path.expand(file) <> "/", @repository <> "/")
  end

  # Writes a temporary file with mode 0600 before any secret goes in, then
  # renames it over the token file, so the previous pair stays readable until
  # the new one is complete.
  defp write_token_file!(file, %{access_token: access, refresh_token: refresh} = token, issued_at) do
    temporary = file <> ".tmp"
    File.write!(temporary, "")
    File.chmod!(temporary, 0o600)

    File.write!(temporary, [
      "TEMPO_OAUTH_ACCESS_TOKEN=#{access}\n",
      "TEMPO_OAUTH_REFRESH_TOKEN=#{refresh}\n",
      expires_at_line(token, issued_at)
    ])

    File.rename!(temporary, file)
  end

  defp write_token_file!(_file, _token, _issued_at), do: flunk("no token pair to write")

  defp expires_at_line(%{expires_in: seconds}, issued_at) when is_integer(seconds) do
    expires_at =
      issued_at |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)

    "TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT=#{DateTime.to_iso8601(expires_at)}\n"
  end

  defp expires_at_line(_token, _issued_at), do: []

  # The recorder redacts token fields by key and checks configured
  # credentials; freshly issued tokens are not configured, so this checks the
  # written fixture for them and for the code.
  defp refute_recorded_secrets!(name, secrets) do
    if LiveSmoke.recording?() do
      path = Path.join([File.cwd!(), "test", "fixtures", "tempo", "recorded", name <> ".json"])
      text = File.read!(path)

      if Enum.any?(secrets, &String.contains?(text, &1)) do
        File.rm!(path)
        flunk("#{name}.json contained a token or the code and was deleted")
      end
    end
  end

  defp oauth_opts(env) do
    [
      client_id: env["TEMPO_OAUTH_CLIENT_ID"],
      client_secret: env["TEMPO_OAUTH_CLIENT_SECRET"],
      redirect_uri: env["TEMPO_OAUTH_REDIRECT_URI"]
    ]
  end

  defp refute_leak(error, secret) do
    leaked? =
      String.contains?(inspect(error), secret) or
        String.contains?(inspect(Error.to_map(error)), secret)

    refute leaked?, "the normalized error contains the token"
  end

  # Prepares and commits the worklog create with direct calls denied. The
  # host evidence names the prepared action, and the validator accepts only
  # that one.
  defp commit(%Context{connection: connection} = context, :api_token, token, input) do
    lease =
      CredentialLease.from_connection!(connection, %{api_token: token},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    opts = [context: context, credential_lease: lease, direct_mutation_mode: :deny]

    with {:ok, prepared} <- Jido.Connect.prepare(Tempo, @create, input, opts) do
      Jido.Connect.commit(
        Tempo,
        prepared,
        input,
        opts ++
          [
            execution_authorization: %{prepared_action_id: prepared.id},
            authorization_validator: fn evidence, prepared, _context ->
              evidence.prepared_action_id == prepared.id
            end
          ]
      )
    end
  end

  # A booking that Tempo should have refused but created: report its ID and
  # stop, so the test sends nothing more.
  defp stop_if_created!({:ok, %{worklog: %{tempo_worklog_id: id}}}, what),
    do: flunk("STOP: Tempo created worklog #{id} for #{what}")

  defp stop_if_created!({:ok, %{"tempoWorklogId" => id}}, what),
    do: flunk("STOP: Tempo created worklog #{id} for #{what}")

  defp stop_if_created!(_result, _what), do: :ok

  # Reason and status only, since Tempo's error text may quote the
  # booking, including the test user's account ID.
  defp error_summary({:error, error}),
    do: "reason #{inspect(Map.get(error, :reason))}, status #{inspect(Map.get(error, :status))}"

  defp error_summary({:ok, _value}), do: "a success"
  defp error_summary(_other), do: "an unexpected result"

  # The compared fields, without the author, whose account ID the output
  # of a failing comparison would show. A description that Tempo left out
  # is nil on both sides.
  defp key(worklog) do
    {worklog.tempo_worklog_id, worklog.start_date, worklog[:start_time],
     worklog[:start_date_time_utc], worklog.time_spent_seconds, worklog[:billable_seconds],
     worklog.issue_id, worklog.description}
  end

  defp raw_key(record) do
    {record["tempoWorklogId"], record["startDate"], record["startTime"],
     record["startDateTimeUtc"], record["timeSpentSeconds"], record["billableSeconds"],
     record["issue"]["id"], record["description"]}
  end

  defp twins?(worklogs) do
    worklogs
    |> Enum.group_by(&Map.drop(&1, [:tempo_worklog_id, :self, :created_at, :updated_at]))
    |> Enum.any?(fn {_shape, group} -> length(group) > 1 end)
  end

  # Reads one approval directly, outside the package and the recorder: the
  # user's own Tempo view of that period.
  defp raw_approval!(env, token, %{from: from, to: to}) do
    path =
      "/4/timesheet-approvals/user/" <> URI.encode(account_id!(env), &URI.char_unreserved?/1)

    case Req.get(env["TEMPO_API_ORIGIN"] <> path,
           auth: {:bearer, token},
           params: [from: from, to: to],
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"status" => %{} = _status} = body}} -> body
      _other -> flunk("the direct Tempo approval read of #{from} to #{to} failed")
    end
  end

  defp raw_evidence(%{"status" => status}), do: {status["key"], status["updatedAt"]}

  defp error_message({:error, %Error.ProviderError{details: %{message: message}}})
       when is_binary(message),
       do: message

  defp error_message(_result), do: ""
end
