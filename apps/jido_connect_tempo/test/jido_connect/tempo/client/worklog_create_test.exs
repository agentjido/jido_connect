defmodule Jido.Connect.Tempo.Client.WorklogCreateTest do
  use ExUnit.Case, async: false

  # `Client.create_worklog/2` against the responses that the live tests
  # recorded on 2026-11-02 for `POST /4/worklogs`:
  #
  # - `worklog_create`: the 200 for worklog 79177, booked on 2026-10-29 at
  #   08:15:00 for 3661 seconds on issue 46097, without billable seconds;
  # - `worklog_create.3`: the 403 for the same booking in the approved
  #   August period;
  # - `worklog_create_invalid_time`: the 400 for a start time of 25:00:00;
  # - `worklog_create_unauthorized`: the 401 for an invented token.
  #
  # The sanitizer recorded the test user as `account-1`, so the request
  # account here is `account-1` too.

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.Client
  alias Jido.Connect.Tempo.Client.Request
  alias Jido.Connect.Tempo.{Fixture, Worklog}

  @account "account-1"
  @token "tempo-api-token-275-secret"
  @marker "JCL live create test"

  setup {Req.Test, :verify_on_exit!}

  setup do
    put_req_options(plug: {Req.Test, __MODULE__})
  end

  describe "payload" do
    test "sends one exact JSON payload for the bound author without bypass or estimate fields" do
      test_pid = self()

      Req.Test.expect(__MODULE__, fn conn ->
        send(test_pid, {:post, conn.method, conn.request_path, payload(conn)})
        created(conn, issue_id: 10_001, seconds: 5400)
      end)

      assert {:ok, %Worklog{issue_id: 10_001, time_spent_seconds: 5400}} =
               Client.create_worklog(request(), %{
                 author_account_id: @account,
                 issue_id: 10_001,
                 start_date: "2026-10-29",
                 time_spent_seconds: 5400
               })

      assert_received {:post, "POST", "/4/worklogs", payload}

      assert payload == %{
               "authorAccountId" => @account,
               "issueId" => 10_001,
               "startDate" => "2026-10-29",
               "timeSpentSeconds" => 5400
             }
    end

    test "adds the given optional fields as sent, attributes as key and value pairs" do
      test_pid = self()

      Req.Test.expect(__MODULE__, fn conn ->
        send(test_pid, {:payload, payload(conn)})
        Fixture.respond(conn, "worklog_create")
      end)

      assert {:ok, %Worklog{}} =
               Client.create_worklog(request(), %{
                 author_account_id: @account,
                 issue_id: 46_097,
                 start_date: "2026-10-29",
                 time_spent_seconds: 3661,
                 description: @marker,
                 start_time: "08:15:00",
                 billable_seconds: 0,
                 attributes: [
                   %{key: "_Phase_", value: "build"},
                   %{"key" => "_Billable_", "value" => "true"}
                 ]
               })

      assert_received {:payload, payload}

      assert payload == %{
               "authorAccountId" => @account,
               "issueId" => 46_097,
               "startDate" => "2026-10-29",
               "timeSpentSeconds" => 3661,
               "description" => @marker,
               "startTime" => "08:15:00",
               "billableSeconds" => 0,
               "attributes" => [
                 %{"key" => "_Phase_", "value" => "build"},
                 %{"key" => "_Billable_", "value" => "true"}
               ]
             }
    end
  end

  describe "checks before POST" do
    setup do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :posted)
        Fixture.respond(conn, "worklog_create")
      end)

      :ok
    end

    test "an issue key, a non-positive or fractional duration and an invalid date or time fail" do
      for {field, value} <- [
            issue_id: "PROJ-123",
            issue_id: "46097",
            issue_id: 0,
            issue_id: -1,
            time_spent_seconds: 0,
            time_spent_seconds: 5400.5,
            time_spent_seconds: 5400.0,
            time_spent_seconds: "5400",
            start_date: "2026-02-30",
            start_date: "29.10.2026",
            start_date: "2026-10-29T08:15:00Z",
            start_date: "+2026-10-29",
            start_time: "25:00:00",
            start_time: "08:60:00",
            start_time: "8:15:00",
            start_time: "08:15",
            start_time: "08:15:00.5",
            start_time: "08:15:00Z",
            billable_seconds: -1,
            billable_seconds: 1.5,
            description: 42
          ] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_worklog_input,
                  subject: ^field,
                  details: %{field: ^field}
                }} = Client.create_worklog(request(), Map.put(valid(), field, value)),
               "#{field} #{inspect(value)} was accepted"
      end

      refute_received :posted
    end

    test "attributes must be key and value strings with unique keys" do
      for attributes <- [
            [%{key: "_Phase_", value: "build"}, %{"key" => "_Phase_", "value" => "test"}],
            [%{key: "", value: "build"}],
            [%{key: "_Phase_"}],
            [%{key: "_Phase_", value: 1}],
            [%{key: "_Phase_", value: "build", self: "https://api.tempo.io/x"}],
            [%{"key" => "_Other_", key: "_Phase_", value: "build"}],
            ["_Phase_"],
            %{key: "_Phase_", value: "build"}
          ] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_worklog_input,
                  subject: :attributes
                }} = Client.create_worklog(request(), Map.put(valid(), :attributes, attributes)),
               "#{inspect(attributes)} was accepted"
      end

      refute_received :posted
    end

    test "a missing required field or any other key fails" do
      for field <- [:author_account_id, :issue_id, :start_date, :time_spent_seconds],
          input <- [Map.delete(valid(), field), Map.put(valid(), field, nil)] do
        assert {:error, %Error.ValidationError{reason: :invalid_worklog_input, subject: ^field}} =
                 Client.create_worklog(request(), input)
      end

      for {key, value} <- [
            bypass_period_closures_and_approvals: true,
            remaining_estimate_seconds: 0,
            body: %{"bypassPeriodClosuresAndApprovals" => true},
            authorAccountId: @account
          ] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_worklog_input,
                  details: %{unknown_keys: [^key]}
                }} = Client.create_worklog(request(), Map.put(valid(), key, value))
      end

      assert {:error, %Error.ValidationError{reason: :invalid_worklog_input, subject: :input}} =
               Client.create_worklog(request(), Map.to_list(valid()))

      refute_received :posted
    end

    test "an author other than the request's account fails without naming either account" do
      for author <- ["account-2", "", " account-1", "ACCOUNT-1"] do
        assert {:error,
                %Error.AuthError{
                  reason: :foreign_worklog_author,
                  connection_id: "tempo_conn_1"
                } = error} =
                 Client.create_worklog(request(), %{valid() | author_account_id: author})

        refute inspect(error) =~ "account-"
      end

      refute_received :posted
    end
  end

  describe "success" do
    test "returns the worklog as Tempo confirmed it" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklog_create"))

      assert {:ok, worklog} =
               Client.create_worklog(request(), %{
                 valid()
                 | start_date: "2026-10-29"
               })

      assert Worklog.to_map(worklog) == %{
               tempo_worklog_id: 79_177,
               author_account_id: @account,
               start_date: "2026-10-29",
               time_spent_seconds: 3661,
               issue_id: 46_097,
               description: @marker,
               work_attributes: [],
               start_time: "08:15:00",
               start_date_time_utc: "2026-10-29T07:15:00Z",
               billable_seconds: 3661,
               created_at: "2026-11-02T18:51:30Z",
               updated_at: "2026-11-02T18:51:30Z",
               self: "https://api.tempo.io/4/worklogs/79177"
             }
    end

    # The test site has work attributes only around an attribute run, so the
    # recorded worklog carries none; this is the recorded 200 with the long
    # description of worklog 79166 and two attribute values in Tempo's form.
    test "keeps a long description and the attribute values whole" do
      long =
        Fixture.recorded!("worklogs_own_day")["body"]["results"] |> hd() |> Map.get("description")

      pairs = [
        %{"key" => "_Phase_", "value" => "build"},
        %{"key" => "_Billable_", "value" => "true"}
      ]

      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklog_create",
          body: fn body ->
            body |> Map.put("description", long) |> put_in(["attributes", "values"], pairs)
          end
        )
      end)

      assert {:ok, %Worklog{description: ^long, work_attributes: attributes}} =
               Client.create_worklog(request(), valid())

      assert byte_size(long) == 778

      assert attributes == [
               %{key: "_Phase_", value: "build"},
               %{key: "_Billable_", value: "true"}
             ]
    end
  end

  describe "uncertain outcomes" do
    # Each is the recorded 200 with one field changed: a worklog that Tempo
    # may have created, but not the one that was asked for.
    test "a confirmed worklog that differs in author, issue, day or seconds is an unknown outcome" do
      for {field, change} <- [
            author_account_id: &put_in(&1, ["author", "accountId"], "account-2"),
            issue_id: &put_in(&1, ["issue", "id"], 46_098),
            start_date: &Map.put(&1, "startDate", "2026-10-30"),
            time_spent_seconds: &Map.put(&1, "timeSpentSeconds", 3660)
          ] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklog_create", body: change))

        assert {:error,
                %Error.ProviderError{
                  reason: :worklog_mismatch,
                  delivery: :sent_outcome_unknown,
                  mutation?: true,
                  provider_idempotency?: false,
                  details: %{tempo_worklog_id: 79_177, mismatched_fields: [^field]}
                } = error} = Client.create_worklog(request(), valid())

        assert Error.retry_guidance(error) == :do_not_retry
        refute inspect(error) =~ "account-"
      end
    end

    # The recorded 200 without its ID or with its body replaced, and the
    # recorded 200's status on a body that is not JSON.
    test "a malformed success is an unknown outcome, never a fabricated worklog" do
      for respond <- [
            &Fixture.respond(&1, "worklog_create",
              body: fn body -> Map.delete(body, "tempoWorklogId") end
            ),
            &Fixture.respond(&1, "worklog_create",
              body: fn body -> Map.put(body, "tempoWorklogId", "79177") end
            ),
            &Fixture.respond(&1, "worklog_create", body: fn body -> [body] end),
            &Fixture.respond(&1, "worklog_create",
              body: fn _body -> "{\"tempoWorklogId\": 79177" end
            ),
            &Fixture.respond(&1, "worklog_create", body: fn _body -> nil end)
          ] do
        Req.Test.expect(__MODULE__, respond)

        assert {:error,
                %Error.ProviderError{
                  delivery: :sent_outcome_unknown,
                  mutation?: true,
                  provider_idempotency?: false
                } = error} = Client.create_worklog(request(), valid())

        assert error.reason in [:invalid_response, :invalid_worklog]
        assert Error.retry_guidance(error) == :do_not_retry
      end
    end
  end

  describe "errors" do
    # 400, 401 and the 403 of a locked period are recorded POST answers. The
    # account produces no other 403 and no 404 on this POST, so these are
    # the recorded 403 and 404 bodies of two reads. 429 and 5xx are the
    # recorded 400 with only the status (and a Retry-After) changed; the
    # transport failures come from Req.Test.transport_error/2.
    test "each failure is a distinct normalized error with its delivery and retry guidance" do
      cases = [
        {"400", &Fixture.respond(&1, "worklog_create_invalid_time")},
        {"401", &Fixture.respond(&1, "worklog_create_unauthorized")},
        {"403 period", &Fixture.respond(&1, "worklog_create.3")},
        {"403", &Fixture.respond(&1, "forbidden")},
        {"404", &Fixture.respond(&1, "not_found")},
        {"429",
         &Fixture.respond(&1, "worklog_create_invalid_time",
           status: 429,
           headers: [{"retry-after", "30"}]
         )},
        {"500", &Fixture.respond(&1, "worklog_create_invalid_time", status: 500)},
        {"503", &Fixture.respond(&1, "worklog_create_invalid_time", status: 503)},
        {"timeout", &Req.Test.transport_error(&1, :timeout)},
        {"closed", &Req.Test.transport_error(&1, :closed)},
        {"refused", &Req.Test.transport_error(&1, :econnrefused)}
      ]

      results =
        for {name, respond} <- cases do
          Req.Test.expect(__MODULE__, respond)

          assert {:error,
                  %Error.ProviderError{
                    provider: :tempo,
                    mutation?: true,
                    provider_idempotency?: false
                  } = error} =
                   Client.create_worklog(request(), Map.put(valid(), :description, @marker))

          refute inspect(error) =~ @marker
          refute inspect(Error.to_map(error)) =~ @token
          {name, {error.reason, error.status, error.delivery, Error.retry_guidance(error)}}
        end

      assert results == [
               {"400", {:bad_request, 400, :rejected, :do_not_retry}},
               {"401", {:unauthorized, 401, :rejected, :do_not_retry}},
               {"403 period", {:period_locked, 403, :rejected, :do_not_retry}},
               {"403", {:forbidden, 403, :rejected, :do_not_retry}},
               {"404", {:not_found, 404, :rejected, :do_not_retry}},
               {"429", {:rate_limited, 429, :rejected, :safe_to_retry}},
               {"500", {:server_error, 500, :sent_outcome_unknown, :do_not_retry}},
               {"503", {:server_error, 503, :sent_outcome_unknown, :do_not_retry}},
               {"timeout", {:request_error, nil, :sent_outcome_unknown, :do_not_retry}},
               {"closed", {:request_error, nil, :sent_outcome_unknown, :do_not_retry}},
               {"refused", {:request_error, nil, :not_sent, :safe_to_retry}}
             ]
    end

    test "the 403 of a locked period keeps Tempo's text and its retry_after" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklog_create.3"))

      assert {:error, %Error.ProviderError{reason: :period_locked, details: details}} =
               Client.create_worklog(request(), valid())

      assert details.message == "The timesheet status must be open for the period"
      assert details.retry_after == nil
    end

    test "a 400 or another 403 that names no locked period is not labelled a period lock" do
      for {status, message} <- [
            {400, "The timesheet status must be open for the period"},
            {403, "You do not have permission to log work for this issue"}
          ] do
        Req.Test.expect(__MODULE__, fn conn ->
          Fixture.respond(conn, "worklog_create.3",
            status: status,
            body: &put_in(&1, ["errors"], [%{"message" => message}])
          )
        end)

        assert {:error, %Error.ProviderError{reason: reason}} =
                 Client.create_worklog(request(), valid())

        assert reason in [:bad_request, :forbidden]
      end
    end

    # Tempo quotes rejected input, as in the recorded `Non valid time
    # '25:00:00'`. This is that recorded 400 with only its errors changed to
    # quote the description, an attribute value and the author. The
    # attribute value `create` is part of the description, so the longer
    # value has to be replaced first.
    test "a 400 that quotes the description, an attribute value or the author redacts them" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklog_create_invalid_time",
          body:
            &put_in(&1, ["errors"], [
              %{"message" => "Non valid description '#{@marker}'"},
              %{"message" => "Non valid value 'create' for work attribute '_Phase_'"},
              %{"message" => "Non valid author '#{@account}'"}
            ])
        )
      end)

      assert {:error,
              %Error.ProviderError{reason: :bad_request, status: 400, delivery: :rejected} =
                error} = Client.create_worklog(request(), echoed(value: "create"))

      assert error.details.message ==
               "Non valid description '[redacted]'; " <>
                 "Non valid value '[redacted]' for work attribute '_Phase_'; " <>
                 "Non valid author '[redacted]'"

      for text <- [inspect(error), inspect(Error.to_map(error))],
          value <- [@marker, "'create'", @account] do
        refute text =~ value
      end
    end

    # The recorded 403 of a locked period with the echo of the description
    # appended. The attribute value `open` occurs in the lock text, so the
    # label has to come from Tempo's text before it is redacted.
    test "a 403 of a locked period that quotes the input stays :period_locked" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklog_create.3",
          body:
            &update_in(&1, ["errors"], fn errors ->
              errors ++ [%{"message" => "Non valid description '#{@marker}'"}]
            end)
        )
      end)

      assert {:error, %Error.ProviderError{reason: :period_locked, status: 403} = error} =
               Client.create_worklog(request(), echoed(value: "open"))

      assert error.details.message ==
               "The timesheet status must be [redacted] for the period; " <>
                 "Non valid description '[redacted]'"

      for text <- [inspect(error), inspect(Error.to_map(error))] do
        refute text =~ @marker
      end
    end
  end

  describe "no automatic second POST" do
    test "retry: :transient in :tempo_req_options sends each create once" do
      put_req_options(plug: {Req.Test, __MODULE__}, retry: :transient, retry_delay: 0)

      for respond <- [
            &Fixture.respond(&1, "worklog_create_invalid_time", status: 503),
            &Fixture.respond(&1, "worklog_create_invalid_time", status: 500),
            &Fixture.respond(&1, "worklog_create_invalid_time", status: 429),
            &Req.Test.transport_error(&1, :timeout),
            &Req.Test.transport_error(&1, :closed)
          ] do
        test_pid = self()

        Req.Test.expect(__MODULE__, 1, fn conn ->
          send(test_pid, :posted)
          respond.(conn)
        end)

        assert {:error, %Error.ProviderError{}} = Client.create_worklog(request(), valid())
        assert_received :posted
        refute_received :posted
      end
    end
  end

  defp valid do
    %{
      author_account_id: @account,
      issue_id: 46_097,
      start_date: "2026-10-29",
      time_spent_seconds: 3661
    }
  end

  # The valid input with the description and one attribute of `value`.
  defp echoed(value: value) do
    Map.merge(valid(), %{description: @marker, attributes: [%{key: "_Phase_", value: value}]})
  end

  defp payload(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end

  # The recorded 200 with the issue ID and the seconds of another booking.
  defp created(conn, issue_id: issue_id, seconds: seconds) do
    Fixture.respond(conn, "worklog_create",
      body: fn body ->
        body
        |> put_in(["issue", "id"], issue_id)
        |> Map.put("timeSpentSeconds", seconds)
      end
    )
  end

  defp request(account_id \\ @account) do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: account_id},
        status: :connected,
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: @token})
    request
  end

  defp put_req_options(options) do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, options)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end
end
