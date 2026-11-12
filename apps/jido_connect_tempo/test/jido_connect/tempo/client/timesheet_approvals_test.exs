defmodule Jido.Connect.Tempo.Client.TimesheetApprovalsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.{Client, Fixture, TimesheetApproval}
  alias Jido.Connect.Tempo.Client.Request

  # Recorded by the live test "reads the open October approval and rejects a
  # range across periods" with the OAuth access token: `timesheet_approval`
  # is the test user's OPEN approval of October 2026, whose status carries
  # only its key, and `timesheet_approval.2` Tempo's 400 for August 1 to
  # September 30. The sanitizer replaced the test user's account ID with
  # `account-1`.
  @account "account-1"
  @october {"2026-10-01", "2026-10-31"}

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

  describe "get_timesheet_approval/3" do
    test "reads one period with its exact boundaries for the connection's account" do
      test_pid = self()

      Req.Test.expect(__MODULE__, fn conn ->
        send(test_pid, {:request, conn.method, conn.request_path, conn.query_string})
        Fixture.respond(conn, "timesheet_approval")
      end)

      assert {:ok, approval} = get(request(), @october)

      assert approval == %TimesheetApproval{
               period_from: "2026-10-01",
               period_to: "2026-10-31",
               user_account_id: @account,
               status: "OPEN",
               updated_at: nil
             }

      assert_received {:request, "GET", "/4/timesheet-approvals/user/account-1", query}
      assert URI.decode_query(query) == %{"from" => "2026-10-01", "to" => "2026-10-31"}
    end

    # The recorded approval of `account-1`, answered for another account.
    test "sends the account ID as one encoded path segment" do
      account = "557058:f0e1/a b"

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/4/timesheet-approvals/user/557058%3Af0e1%2Fa%20b"

        Fixture.respond(conn, "timesheet_approval",
          body: &put_in(&1, ["user", "accountId"], account)
        )
      end)

      assert {:ok, %TimesheetApproval{user_account_id: ^account, status: "OPEN"}} =
               get(request(account), @october)
    end

    # Recorded by the period bookability live test, where the test user is
    # `account-2` and the reviewer `account-1`: August is APPROVED and
    # September IN_REVIEW, each with the time of its status.
    test "keeps the recorded APPROVED and IN_REVIEW status with its time and nothing else" do
      for {fixture, {from, to}, status, updated_at} <- [
            {"period_bookability.2", {"2026-08-01", "2026-08-31"}, "APPROVED",
             "2026-10-30T19:19:42Z"},
            {"period_bookability.3", {"2026-09-01", "2026-09-30"}, "IN_REVIEW",
             "2026-10-30T19:19:43Z"}
          ] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, fixture))

        assert {:ok, approval} = get(request("account-2"), {from, to})

        assert approval == %TimesheetApproval{
                 period_from: from,
                 period_to: to,
                 user_account_id: "account-2",
                 status: status,
                 updated_at: updated_at
               }

        refute inspect(approval) =~ "account-1"
        refute inspect(approval) =~ "JCL live seed"
      end
    end

    test "a range across periods gets Tempo's 400 as a normalized error" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "timesheet_approval.2"))

      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :bad_request,
                status: 400,
                details: %{message: message}
              }} = get(request(), {"2026-08-01", "2026-09-30"})

      assert message ==
               "This is not a valid period. Did you mean from '2026-08-01' to '2026-08-31'?"
    end

    test "an invalid or reversed range fails before any request" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, "timesheet_approval")
      end)

      for {range, field} <- [
            {{"2026-10-32", "2026-10-31"}, :from},
            {{nil, "2026-10-31"}, :from},
            {{"2026-10-01", "2026/10/31"}, :to},
            {{"2026-10-31", "2026-10-01"}, :to}
          ] do
        assert {:error,
                %Error.ValidationError{reason: :invalid_date_range, details: %{field: ^field}}} =
                 get(request(), range)
      end

      refute_received :requested
    end
  end

  describe "the answer must match the request" do
    # The recorded approval with `user.accountId` replaced.
    test "an approval of another user fails without naming that user" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "timesheet_approval",
          body: &put_in(&1, ["user", "accountId"], "account-2")
        )
      end)

      assert {:error,
              %Error.ProviderError{
                reason: :foreign_approval_user,
                delivery: :response_received,
                details: details
              } = error} = get(request(), @october)

      assert details == %{from: "2026-10-01", to: "2026-10-31"}
      refute inspect(error) =~ "account-2"
    end

    # The recorded approval with `period.to` or `period.from` replaced.
    test "an approval of another period fails" do
      for {field, value, returned} <- [
            {"to", "2026-10-15", {"2026-10-01", "2026-10-15"}},
            {"from", "2026-10-02", {"2026-10-02", "2026-10-31"}}
          ] do
        Req.Test.expect(__MODULE__, fn conn ->
          Fixture.respond(conn, "timesheet_approval", body: &put_in(&1, ["period", field], value))
        end)

        {period_from, period_to} = returned

        assert {:error,
                %Error.ProviderError{
                  reason: :approval_period_mismatch,
                  details: %{
                    from: "2026-10-01",
                    to: "2026-10-31",
                    period_from: ^period_from,
                    period_to: ^period_to
                  }
                }} = get(request(), @october)
      end
    end
  end

  describe "normalization" do
    # The recorded approval without its status, or with its key removed.
    test "a missing status stays nil and is never OPEN" do
      for change <- [&Map.delete(&1, "status"), &Map.put(&1, "status", %{})] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, "timesheet_approval", body: change))

        assert {:ok, %TimesheetApproval{status: nil, updated_at: nil}} = get(request(), @october)
      end
    end

    # No recording holds a key other than OPEN, IN_REVIEW or APPROVED.
    test "an unfamiliar status key stays the raw string and creates no atom" do
      key = "PENDING_PAYROLL_REVIEW_" <> Integer.to_string(System.unique_integer([:positive]))

      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "timesheet_approval", body: &put_in(&1, ["status", "key"], key))
      end)

      assert {:ok, %TimesheetApproval{status: ^key}} = get(request(), @october)
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    # The recorded approval with one field removed or broken.
    test "a missing or malformed field fails with its Tempo path" do
      for {change, field} <- [
            {&Map.delete(&1, "user"), "user.accountId"},
            {&put_in(&1, ["user", "accountId"], ""), "user.accountId"},
            {&Map.put(&1, "user", "account-1"), "user.accountId"},
            {&Map.delete(&1, "period"), "period.from"},
            {&put_in(&1, ["period", "to"], "2026-10-32"), "period.to"},
            {&put_in(&1, ["status", "key"], 1), "status.key"},
            {&put_in(&1, ["status", "key"], ""), "status.key"},
            {&put_in(&1, ["status", "updatedAt"], 1_793_142_000), "status.updatedAt"},
            {&Map.put(&1, "status", "OPEN"), "status.key"},
            {fn _body -> [] end, "approval"}
          ] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, "timesheet_approval", body: change))

        assert {:error,
                %Error.ProviderError{
                  reason: :invalid_timesheet_approval,
                  details: %{field: ^field}
                }} = get(request(), @october)
      end
    end
  end

  defp get(request, {from, to}), do: Client.get_timesheet_approval(request, from, to)

  defp request(account_id \\ @account) do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :oauth2_user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: account_id},
        status: :connected,
        scopes: ["tempo.approvals.read"],
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{access_token: "tempo-oauth-token-274"})
    request
  end
end
