defmodule Jido.Connect.Tempo.GetPeriodBookabilityActionTest do
  use ExUnit.Case, async: false

  # `tempo.period.bookability.get` through the runtime and through the
  # generated Jido action, against the reads that the live test "the period
  # bookability of the seeded periods matches the user's Tempo view"
  # recorded for August 15 to October 15, 2026: `period_bookability` holds
  # the three monthly periods, `.2` the APPROVED August approval, `.3` the
  # IN_REVIEW September approval and `.4` the OPEN October approval. The
  # sanitizer numbered the reviewer of August first, so the test user is
  # `account-2` and the reviewer `account-1`.
  #
  # The test account cannot produce a gap in period coverage, a period
  # outside the range, another user's approval, an unfamiliar or missing
  # status, a failed subrequest or non-monthly periods with a leap day.
  # Those cases change only the fields they need in the recorded responses,
  # and each test says which.

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Actions.GetPeriodBookability
  alias Jido.Connect.Tempo.{Fixture, TimesheetApproval}

  @action "tempo.period.bookability.get"
  @account "account-2"
  @api_token "tempo-api-token-274-secret"
  @access_token "tempo-oauth-token-274-secret"
  @range %{from: "2026-08-15", to: "2026-10-15"}
  @scopes ["tempo.periods.read", "tempo.approvals.read"]
  @approvals %{
    "2026-08-01" => "period_bookability.2",
    "2026-09-01" => "period_bookability.3",
    "2026-10-01" => "period_bookability.4"
  }

  defmodule RecordingClient do
    @moduledoc false

    # A provider client that reports each call and answers with the
    # recorded periods and approvals, normalized as the built-in client does.

    alias Jido.Connect.Tempo.{Fixture, TimesheetApproval}

    @approvals %{
      "2026-08-01" => "period_bookability.2",
      "2026-09-01" => "period_bookability.3",
      "2026-10-01" => "period_bookability.4"
    }

    def list_periods(request, opts) do
      send(self(), {:list_periods, request, opts})

      {:ok,
       for period <- Fixture.recorded!("period_bookability")["body"]["periods"] do
         %{from: period["from"], to: period["to"]}
       end}
    end

    def get_timesheet_approval(request, from, to) do
      send(self(), {:get_timesheet_approval, request, from, to})
      body = Fixture.recorded!(@approvals[from])["body"]
      {:ok, approval} = TimesheetApproval.normalize(body)
      {:ok, %{approval | user_account_id: request.account_id}}
    end
  end

  defmodule FailingApprovalClient do
    @moduledoc false

    # Answers the recorded periods like RecordingClient, but every approval
    # read fails with an error that is not a Tempo provider error with an
    # atom reason, as a host's own client might return.

    alias Jido.Connect.Error
    alias Jido.Connect.Tempo.GetPeriodBookabilityActionTest.RecordingClient

    defdelegate list_periods(request, opts), to: RecordingClient

    def get_timesheet_approval(_request, "2026-08-01", _to), do: {:error, :econnrefused}

    def get_timesheet_approval(_request, "2026-09-01", _to),
      do: {:error, Error.validation("Host check failed: secret detail", reason: :host_check)}

    def get_timesheet_approval(_request, "2026-10-01", _to),
      do:
        {:error,
         Error.provider("Host text", provider: :tempo, reason: "host reason", status: 502)}
  end

  defmodule NextSecondClient do
    @moduledoc false

    # Answers like RecordingClient, but reads the periods only once the
    # next full UTC second has begun and reports that time. A checked_at
    # taken before this read is therefore an earlier second than the read.

    alias Jido.Connect.Tempo.GetPeriodBookabilityActionTest.RecordingClient

    def list_periods(request, opts) do
      next_second =
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(1, :second)

      wait_until(next_second)
      send(self(), {:periods_read_at, DateTime.utc_now()})
      RecordingClient.list_periods(request, opts)
    end

    defdelegate get_timesheet_approval(request, from, to), to: RecordingClient

    defp wait_until(time) do
      case DateTime.diff(time, DateTime.utc_now(), :microsecond) do
        wait when wait > 0 ->
          Process.sleep(div(wait, 1000) + 1)
          wait_until(time)

        _reached ->
          :ok
      end
    end
  end

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end

  describe "evidence" do
    test "returns the recorded evidence of every intersecting period with one GET each" do
      serve()

      assert {:ok, result} = invoke(:api_token, @range)

      assert %{
               account_id: @account,
               from: "2026-08-15",
               to: "2026-10-15",
               checked_at: checked_at,
               complete: true,
               state: :blocked,
               segments: segments
             } = result

      assert is_binary(checked_at)

      assert segments == [
               %{
                 from: "2026-08-15",
                 to: "2026-08-31",
                 period_from: "2026-08-01",
                 period_to: "2026-08-31",
                 approval_status: "APPROVED",
                 approval_updated_at: "2026-10-30T19:19:42Z",
                 approval_error: nil,
                 closure_evidence: :unknown,
                 state: :blocked
               },
               %{
                 from: "2026-09-01",
                 to: "2026-09-30",
                 period_from: "2026-09-01",
                 period_to: "2026-09-30",
                 approval_status: "IN_REVIEW",
                 approval_updated_at: "2026-10-30T19:19:43Z",
                 approval_error: nil,
                 closure_evidence: :unknown,
                 state: :blocked
               },
               %{
                 from: "2026-10-01",
                 to: "2026-10-15",
                 period_from: "2026-10-01",
                 period_to: "2026-10-31",
                 approval_status: "OPEN",
                 approval_updated_at: nil,
                 approval_error: nil,
                 closure_evidence: :unknown,
                 state: :unknown
               }
             ]

      assert requests() == [
               {"GET", "/4/periods", %{"from" => "2026-08-15", "to" => "2026-10-15"}},
               {"GET", "/4/timesheet-approvals/user/account-2",
                %{"from" => "2026-08-01", "to" => "2026-08-31"}},
               {"GET", "/4/timesheet-approvals/user/account-2",
                %{"from" => "2026-09-01", "to" => "2026-09-30"}},
               {"GET", "/4/timesheet-approvals/user/account-2",
                %{"from" => "2026-10-01", "to" => "2026-10-31"}}
             ]

      assert {:ok, _json} = Jason.encode(result)
    end

    # The periods read starts only in the next full second, so a checked_at
    # taken after it would be that second or later.
    test "checked_at is a UTC second taken before the first request" do
      context = context(:api_token)
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, %{checked_at: checked_at}} =
               GetPeriodBookability.run(@range, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: NextSecondClient
               })

      assert_received {:periods_read_at, periods_read_at}
      assert {:ok, checked_at_time, 0} = DateTime.from_iso8601(checked_at)
      assert checked_at =~ ~r/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/
      assert DateTime.compare(checked_at_time, before) != :lt

      assert DateTime.compare(checked_at_time, DateTime.truncate(periods_read_at, :second)) ==
               :lt
    end

    # The recorded periods reduced to those that Tempo returns for each range.
    test "a range on a period's last or first day includes that period" do
      for {range, keep, segments, state} <- [
            {%{from: "2026-08-31", to: "2026-08-31"}, [0],
             [{"2026-08-31", "2026-08-31", "2026-08-01", "2026-08-31", "APPROVED", :blocked}],
             :blocked},
            {%{from: "2026-10-01", to: "2026-10-01"}, [2],
             [{"2026-10-01", "2026-10-01", "2026-10-01", "2026-10-31", "OPEN", :unknown}],
             :unknown},
            {%{from: "2026-08-31", to: "2026-09-01"}, [0, 1],
             [
               {"2026-08-31", "2026-08-31", "2026-08-01", "2026-08-31", "APPROVED", :blocked},
               {"2026-09-01", "2026-09-01", "2026-09-01", "2026-09-30", "IN_REVIEW", :blocked}
             ], :blocked}
          ] do
        serve(periods: keep_periods(keep))

        assert {:ok, %{complete: true, state: ^state} = result} = invoke(:api_token, range)

        assert Enum.map(
                 result.segments,
                 &{&1.from, &1.to, &1.period_from, &1.period_to, &1.approval_status, &1.state}
               ) == segments

        assert approval_requests() == Enum.map(segments, &elem(&1, 2))
      end
    end

    # The recorded periods reduced to October.
    test "an open period alone derives unknown" do
      serve(periods: keep_periods([2]))

      assert {:ok,
              %{
                complete: true,
                state: :unknown,
                segments: [%{approval_status: "OPEN", state: :unknown}]
              }} = invoke(:api_token, %{from: "2026-10-01", to: "2026-10-15"})
    end

    # The recorded periods in reverse order.
    test "segments and approval reads follow the date order, not Tempo's order" do
      serve(periods: keep_periods([2, 1, 0]))

      assert {:ok, %{complete: true, state: :blocked, segments: segments}} =
               invoke(:api_token, @range)

      assert Enum.map(segments, & &1.period_from) == ["2026-08-01", "2026-09-01", "2026-10-01"]
      assert approval_requests() == ["2026-08-01", "2026-09-01", "2026-10-01"]
    end

    # Weekly periods from Wednesday to Tuesday around February 29, 2028: the
    # recorded periods with their dates replaced, the APPROVED and the OPEN
    # approval with `period` and `user.accountId` replaced.
    test "a range across two non-monthly periods and a leap day reads each exact period" do
      account = "557058:f0e1/a b"

      serve(
        periods: fn body ->
          Map.put(body, "periods", [
            %{"from" => "2028-02-23", "to" => "2028-02-29"},
            %{"from" => "2028-03-01", "to" => "2028-03-07"}
          ])
        end,
        approvals: %{
          "2028-02-23" =>
            {"period_bookability.2", &approval(&1, "2028-02-23", "2028-02-29", account)},
          "2028-03-01" =>
            {"period_bookability.4", &approval(&1, "2028-03-01", "2028-03-07", account)}
        }
      )

      assert {:ok, result} =
               invoke(:api_token, %{from: "2028-02-26", to: "2028-03-03"}, account_id: account)

      path = "/4/timesheet-approvals/user/557058%3Af0e1%2Fa%20b"

      assert requests() == [
               {"GET", "/4/periods", %{"from" => "2028-02-26", "to" => "2028-03-03"}},
               {"GET", path, %{"from" => "2028-02-23", "to" => "2028-02-29"}},
               {"GET", path, %{"from" => "2028-03-01", "to" => "2028-03-07"}}
             ]

      assert %{account_id: ^account, complete: true, state: :blocked} = result

      assert Enum.map(result.segments, &{&1.from, &1.to, &1.period_from, &1.period_to, &1.state}) ==
               [
                 {"2028-02-26", "2028-02-29", "2028-02-23", "2028-02-29", :blocked},
                 {"2028-03-01", "2028-03-03", "2028-03-01", "2028-03-07", :unknown}
               ]
    end

    # The recorded September approval with `status.key` replaced.
    test "an unfamiliar status key stays raw, creates no atom and derives unknown" do
      key = "PENDING_PAYROLL_REVIEW_" <> Integer.to_string(System.unique_integer([:positive]))

      serve(
        approvals: %{
          "2026-09-01" => {"period_bookability.3", &put_in(&1, ["status", "key"], key)}
        }
      )

      assert {:ok, %{complete: true, state: :blocked, segments: [august, september, october]}} =
               invoke(:api_token, @range)

      assert %{approval_status: ^key, closure_evidence: :unknown, state: :unknown} = september
      assert %{approval_status: "APPROVED", state: :blocked} = august
      assert %{approval_status: "OPEN", state: :unknown} = october
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    # The recorded August approval without its status, or without its key.
    test "a missing status is recorded as missing, never as OPEN" do
      for change <- [&Map.delete(&1, "status"), &Map.put(&1, "status", %{})] do
        serve(approvals: %{"2026-08-01" => {"period_bookability.2", change}})

        assert {:ok, %{complete: false, state: :blocked, segments: [august, september, _october]}} =
                 invoke(:api_token, @range)

        assert %{
                 approval_status: nil,
                 approval_updated_at: nil,
                 approval_error: nil,
                 state: :unknown
               } = august

        assert %{approval_status: "IN_REVIEW", state: :blocked} = september
      end
    end
  end

  describe "incomplete evidence" do
    # The recorded periods with one or all removed, or with August twice.
    test "a gap or an overlap in period coverage sets complete false and keeps blocked segments" do
      for {keep, read, state} <- [
            {[0, 2], ["2026-08-01", "2026-10-01"], :blocked},
            {[1, 2], ["2026-09-01", "2026-10-01"], :blocked},
            {[0, 1], ["2026-08-01", "2026-09-01"], :blocked},
            {[0, 0, 1, 2], ["2026-08-01", "2026-08-01", "2026-09-01", "2026-10-01"], :blocked},
            {[], [], :unknown}
          ] do
        serve(periods: keep_periods(keep))

        assert {:ok, %{complete: false, state: ^state, segments: segments}} =
                 invoke(:api_token, @range)

        assert Enum.map(segments, & &1.period_from) == read
        assert approval_requests() == read

        for segment <- segments, segment.approval_status in ["APPROVED", "IN_REVIEW"] do
          assert segment.state == :blocked
        end
      end
    end

    # The recorded periods with July 2026 added before and November after.
    test "a period outside the range is neither read nor reported" do
      serve(
        periods:
          &Map.update!(&1, "periods", fn periods ->
            [%{"from" => "2026-07-01", "to" => "2026-07-31"}] ++
              periods ++ [%{"from" => "2026-11-01", "to" => "2026-11-30"}]
          end)
      )

      assert {:ok, %{complete: true, segments: segments}} = invoke(:api_token, @range)
      assert Enum.map(segments, & &1.period_from) == ["2026-08-01", "2026-09-01", "2026-10-01"]
      assert approval_requests() == ["2026-08-01", "2026-09-01", "2026-10-01"]
    end

    # The recorded September approval naming the recorded reviewer as user.
    test "an approval of another user is not evidence and sets complete false" do
      serve(
        approvals: %{
          "2026-09-01" =>
            {"period_bookability.3", &put_in(&1, ["user", "accountId"], "account-1")}
        }
      )

      assert {:ok, %{complete: false, state: :blocked, segments: [august, september, _]} = result} =
               invoke(:api_token, @range)

      assert %{approval_status: "APPROVED", state: :blocked} = august

      assert %{
               approval_status: nil,
               approval_updated_at: nil,
               approval_error: %{reason: :foreign_approval_user, status: nil, retry_after: nil},
               state: :unknown
             } = september

      refute inspect(result) =~ "account-1"
    end

    # The recorded September approval answered with 503, not at all, and
    # with 429 and a Retry-After header.
    test "a failed subrequest sets complete false, keeps blocked segments and names the failure" do
      for {failure, approval_error} <- [
            {fn conn -> Fixture.respond(conn, "period_bookability.3", status: 503) end,
             %{reason: :server_error, status: 503, retry_after: nil}},
            {fn conn -> Req.Test.transport_error(conn, :timeout) end,
             %{reason: :request_error, status: nil, retry_after: nil}},
            {fn conn ->
               Fixture.respond(conn, "period_bookability.3",
                 status: 429,
                 headers: [{"retry-after", "30"}]
               )
             end, %{reason: :rate_limited, status: 429, retry_after: 30}}
          ] do
        serve(approvals: %{"2026-09-01" => failure})

        assert {:ok, %{complete: false, state: :blocked, segments: [august, september, october]}} =
                 invoke(:oauth2_user, @range)

        assert %{approval_status: "APPROVED", approval_error: nil, state: :blocked} = august

        assert %{approval_status: nil, approval_error: ^approval_error, state: :unknown} =
                 september

        assert %{approval_status: "OPEN", approval_error: nil, state: :unknown} = october
      end
    end

    # Tempo's recorded 400 for a range across periods, answered with 403 for
    # every approval: a token that may read periods but not approvals.
    test "a forbidden approval read leaves every segment without evidence and names the 403" do
      forbidden = fn conn -> Fixture.respond(conn, "timesheet_approval.2", status: 403) end

      serve(
        approvals: %{
          "2026-08-01" => forbidden,
          "2026-09-01" => forbidden,
          "2026-10-01" => forbidden
        }
      )

      assert {:ok, %{complete: false, state: :unknown, segments: segments} = result} =
               invoke(:api_token, @range)

      assert Enum.map(segments, &{&1.period_from, &1.approval_status, &1.state}) == [
               {"2026-08-01", nil, :unknown},
               {"2026-09-01", nil, :unknown},
               {"2026-10-01", nil, :unknown}
             ]

      for segment <- segments do
        assert segment.approval_error == %{reason: :forbidden, status: 403, retry_after: nil}
      end

      refute inspect(result) =~ "not a valid period"
      assert approval_requests() == ["2026-08-01", "2026-09-01", "2026-10-01"]
    end

    test "any other approval error is a read failure without its content" do
      context = context(:api_token)

      assert {:ok, %{complete: false, state: :unknown, segments: [_, _, _] = segments} = result} =
               GetPeriodBookability.run(@range, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: FailingApprovalClient
               })

      for segment <- segments do
        assert %{approval_status: nil, state: :unknown} = segment

        assert segment.approval_error == %{
                 reason: :approval_read_failed,
                 status: nil,
                 retry_after: nil
               }
      end

      for text <- ["econnrefused", "secret detail", "host_check", "Host text", "host reason"] do
        refute inspect(result) =~ text
      end
    end

    # The recorded periods answered with 429 and a Retry-After header.
    test "a failed periods read returns the normalized error and reads no approval" do
      serve(
        periods_response: fn conn ->
          Fixture.respond(conn, "period_bookability",
            status: 429,
            headers: [{"retry-after", "30"}]
          )
        end
      )

      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :rate_limited,
                status: 429,
                details: %{retry_after: 30}
              } = error} = invoke(:api_token, @range)

      assert approval_requests() == []

      for text <- [inspect(error), inspect(Error.to_map(error))],
          secret <- [@api_token, @access_token] do
        refute text =~ secret
      end
    end
  end

  describe "period limit" do
    # The recorded periods replaced by twenty monthly periods from January
    # 2026, each answered with the recorded OPEN approval with `period`
    # replaced.
    test "a range of twenty periods reads each of them" do
      periods = months(20)
      serve(periods: &Map.put(&1, "periods", periods), approvals: open_approvals(periods))

      assert {:ok, %{complete: true, segments: segments}} =
               invoke(:api_token, %{from: "2026-01-01", to: "2027-08-31"})

      firsts = Enum.map(periods, & &1["from"])
      assert Enum.map(segments, & &1.period_from) == firsts
      assert approval_requests() == firsts
    end

    # The recorded periods replaced by twenty-one monthly periods.
    test "a range of more than twenty periods fails before any approval read" do
      serve(periods: &Map.put(&1, "periods", months(21)))

      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :period_limit_exceeded,
                delivery: :response_received,
                details: %{max_periods: 20}
              }} = invoke(:api_token, %{from: "2026-01-01", to: "2027-09-30"})

      assert requests() == [
               {"GET", "/4/periods", %{"from" => "2026-01-01", "to" => "2027-09-30"}}
             ]
    end
  end

  describe "output" do
    test "omits approval comments, reviewer profiles and action URLs" do
      serve()

      assert {:ok, result} = invoke(:api_token, @range)
      assert {:ok, json} = Jason.encode(result)

      for text <- [inspect(result), json],
          recorded <- [
            "JCL live seed",
            "account-1",
            "reviewer",
            "actor",
            "comment",
            "actions",
            "submit",
            "recall",
            "self",
            "requiredSeconds",
            "https://"
          ] do
        refute text =~ recorded
      end
    end

    test "the generated action reads with the OAuth profile" do
      serve()
      context = context(:oauth2_user)

      assert {:ok, %{account_id: @account, complete: true, state: :blocked}} =
               GetPeriodBookability.run(@range, %{
                 integration_context: context,
                 credential_lease: lease(context)
               })
    end

    test "the account comes from subject.account_id through the provider client seam" do
      context = context(:api_token)

      assert {:ok, %{account_id: @account, complete: true}} =
               GetPeriodBookability.run(@range, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: RecordingClient
               })

      assert_received {:list_periods, %{account_id: @account}, opts}
      assert opts == [from: "2026-08-15", to: "2026-10-15"]

      for {from, to} <- [
            {"2026-08-01", "2026-08-31"},
            {"2026-09-01", "2026-09-30"},
            {"2026-10-01", "2026-10-31"}
          ] do
        assert_received {:get_timesheet_approval, %{account_id: @account}, ^from, ^to}
      end
    end
  end

  describe "gates before HTTP" do
    setup do
      serve()
      :ok
    end

    test "a missing, invalid or reversed range fails before any request" do
      for input <- [
            %{from: "2026-08-15"},
            %{to: "2026-10-15"},
            %{from: "2026-10-15", to: "2026-08-15"},
            %{from: "2026-02-29", to: "2026-03-01"},
            %{from: "2026-08-15T00:00:00Z", to: "2026-10-15"},
            %{from: "2026-08-15", to: "15.10.2026"}
          ] do
        assert {:error, %Error.ValidationError{}} = invoke(:api_token, input)
      end

      assert requests() == []
    end

    test "an invalid range fails before an injected provider client is called" do
      context = context(:api_token)

      for {input, field} <- [
            {%{from: "2026-10-15", to: "2026-08-15"}, :to},
            {%{from: "2026-02-29", to: "2026-03-01"}, :from}
          ] do
        assert {:error,
                %Error.ValidationError{reason: :invalid_date_range, details: %{field: ^field}}} =
                 GetPeriodBookability.run(input, %{
                   integration_context: context,
                   credential_lease: lease(context),
                   provider_client: RecordingClient
                 })
      end

      refute_received {:list_periods, _request, _opts}
    end

    test "no input selects another account" do
      for extra <- [%{account_id: "account-1"}, %{accountId: "account-1"}, %{user: "account-1"}] do
        assert {:error, %Error.ValidationError{reason: :input}} =
                 invoke(:api_token, Map.merge(@range, extra))
      end

      assert requests() == []
    end

    test "a missing tempo.periods.read or tempo.approvals.read grant stops the call" do
      for {scopes, missing} <- [
            {["tempo.approvals.read"], ["tempo.periods.read"]},
            {["tempo.periods.read", "tempo.worklogs.read"], ["tempo.approvals.read"]},
            {["tempo.worklogs.read"], ["tempo.periods.read", "tempo.approvals.read"]}
          ] do
        assert {:error, %Error.AuthError{reason: :missing_scopes, missing_scopes: ^missing}} =
                 invoke(:api_token, @range, scopes: scopes)
      end

      assert requests() == []
    end

    test "an expired lease or a connection without subject.account_id stops the call" do
      context = context(:api_token)
      expired = lease(context, expires_at: DateTime.add(DateTime.utc_now(), -1, :second))

      assert {:error, %Error.AuthError{}} =
               Connect.invoke(Tempo, @action, @range, context: context, credential_lease: expired)

      context = context(:api_token, account_id: nil)

      assert {:error, %Error.AuthError{reason: :tempo_account_id_required}} =
               Connect.invoke(Tempo, @action, @range,
                 context: context,
                 credential_lease: lease(context)
               )

      assert requests() == []
    end
  end

  # Answers every Tempo request from the recordings and reports it as
  # `{:request, method, path, query}`. Options: `:periods` changes the
  # recorded periods body, `:periods_response` replaces the periods
  # response, and `:approvals` maps a period's first day to a function that
  # answers the request, or to `{fixture, change}` for a changed body.
  defp serve(opts \\ []) do
    test_pid = self()
    approvals = Keyword.get(opts, :approvals, %{})

    periods =
      Keyword.get(opts, :periods_response, fn conn ->
        Fixture.respond(conn, "period_bookability", body: Keyword.get(opts, :periods, & &1))
      end)

    Req.Test.stub(__MODULE__, fn conn ->
      query = URI.decode_query(conn.query_string)
      send(test_pid, {:request, conn.method, conn.request_path, query})

      case {conn.request_path, Map.get(approvals, query["from"])} do
        {"/4/periods", _approval} -> periods.(conn)
        {_path, {fixture, change}} -> Fixture.respond(conn, fixture, body: change)
        {_path, answer} when is_function(answer, 1) -> answer.(conn)
        {_path, nil} -> Fixture.respond(conn, Map.fetch!(@approvals, query["from"]))
      end
    end)
  end

  defp requests(acc \\ []) do
    receive do
      {:request, method, path, query} -> requests([{method, path, query} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp approval_requests do
    for {_method, "/4/timesheet-approvals/user/" <> _, query} <- requests(), do: query["from"]
  end

  # `count` monthly periods from January 2026 on, in Tempo's form.
  defp months(count) do
    for month <- 0..(count - 1) do
      first = Date.shift(~D[2026-01-01], month: month)
      %{"from" => Date.to_iso8601(first), "to" => Date.to_iso8601(Date.end_of_month(first))}
    end
  end

  # The recorded OPEN approval for each period, with `period` replaced.
  defp open_approvals(periods) do
    Map.new(periods, fn %{"from" => from, "to" => to} ->
      {from, {"period_bookability.4", &approval(&1, from, to, @account)}}
    end)
  end

  # Keeps the recorded periods at the given indexes, in the given order.
  defp keep_periods(indexes) do
    &Map.update!(&1, "periods", fn periods ->
      Enum.map(indexes, fn i -> Enum.at(periods, i) end)
    end)
  end

  defp approval(body, from, to, account) do
    body
    |> Map.put("period", %{"from" => from, "to" => to})
    |> put_in(["user", "accountId"], account)
  end

  defp invoke(profile, input, opts \\ []) do
    context = context(profile, opts)
    Connect.invoke(Tempo, @action, input, context: context, credential_lease: lease(context))
  end

  defp context(profile, opts \\ []) do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: Keyword.get(opts, :account_id, @account)},
        status: :connected,
        scopes: Keyword.get(opts, :scopes, @scopes),
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    Context.new!(%{
      tenant_id: "tenant_1",
      actor: %{id: "user_1", type: :app_user},
      connection: connection
    })
  end

  defp lease(%Context{connection: connection}, opts \\ []) do
    fields =
      case connection.profile do
        :api_token -> %{api_token: @api_token}
        :oauth2_user -> %{access_token: @access_token}
      end

    CredentialLease.from_connection!(connection, fields,
      expires_at:
        Keyword.get_lazy(opts, :expires_at, fn -> DateTime.add(DateTime.utc_now(), 60) end)
    )
  end
end
