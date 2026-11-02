defmodule Jido.Connect.Tempo.ListOwnWorklogsActionTest do
  use ExUnit.Case, async: false

  # `tempo.worklogs.list_own` through the runtime and through the generated
  # Jido action, against the reads that the live tests recorded: the 60
  # worklogs from August 1 to October 31, 2026 on `worklogs_own` (50, with a
  # `next` link) and `worklogs_own.2` (10, without one), the empty answer for
  # July on `worklogs_own_empty.2`, and October 28 on `worklogs_own_jira`,
  # where two worklogs created in Jira have an empty description.

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Actions.ListOwnWorklogs
  alias Jido.Connect.Tempo.Fixture

  @action "tempo.worklogs.list_own"
  @account "account-1"
  @api_token "tempo-api-token-272-secret"
  @access_token "tempo-oauth-token-272-secret"
  @periods %{from: "2026-08-01", to: "2026-10-31"}

  defmodule RecordingClient do
    @moduledoc false

    # A provider client that reports its call and returns no worklogs.
    def list_own_worklogs(request, opts) do
      send(self(), {:list_own_worklogs, request, opts})
      {:ok, []}
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

  describe "output" do
    test "returns the own worklogs of the range as plain maps with complete true" do
      expect_pages(["worklogs_own", "worklogs_own.2"])

      assert {:ok, result} = invoke(:api_token, @periods)

      assert %{
               account_id: @account,
               from: "2026-08-01",
               to: "2026-10-31",
               complete: true,
               worklogs: [first | _rest] = worklogs
             } = result

      assert length(worklogs) == 60
      refute is_struct(first)

      assert first == %{
               tempo_worklog_id: 79_093,
               author_account_id: @account,
               start_date: "2026-08-01",
               time_spent_seconds: 5400,
               issue_id: 46_097,
               description: "JCL live seed worklog: approved period, first day",
               work_attributes: [],
               start_time: "09:00:00",
               start_date_time_utc: "2026-08-01T07:00:00Z",
               billable_seconds: 5400,
               created_at: "2026-10-30T19:19:04Z",
               updated_at: "2026-10-30T19:19:04Z",
               self: "https://api.tempo.io/4/worklogs/79093"
             }

      # The output keeps the recorded description of 778 bytes whole and
      # zero billable seconds as 0.
      by_id = Map.new(worklogs, &{&1.tempo_worklog_id, &1})
      long = recorded("worklogs_own.2", 79_166)["description"]
      assert byte_size(long) == 778
      assert %{description: ^long} = by_id[79_166]
      assert %{billable_seconds: 0, time_spent_seconds: 900} = by_id[79_101]

      assert {:ok, _json} = Jason.encode(result)
    end

    test "the generated action reads with the OAuth profile" do
      expect_pages(["worklogs_own", "worklogs_own.2"])
      context = context(:oauth2_user)

      assert {:ok, %{account_id: @account, complete: true, worklogs: [_ | _]}} =
               ListOwnWorklogs.run(@periods, %{
                 integration_context: context,
                 credential_lease: lease(context)
               })
    end

    test "the account comes from subject.account_id through the provider client seam" do
      context = context(:api_token, account_id: "557058:own-account")

      assert {:ok, %{account_id: "557058:own-account", worklogs: [], complete: true} = result} =
               ListOwnWorklogs.run(@periods, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: RecordingClient
               })

      assert result.from == "2026-08-01" and result.to == "2026-10-31"
      assert_received {:list_own_worklogs, request, opts}
      assert request.account_id == "557058:own-account"
      assert opts == [from: "2026-08-01", to: "2026-10-31"]
    end

    test "an empty range returns worklogs [] and complete true" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_own_empty.2"))

      assert {:ok,
              %{
                account_id: @account,
                from: "2026-07-01",
                to: "2026-07-31",
                worklogs: [],
                complete: true
              }} = invoke(:oauth2_user, %{from: "2026-07-01", to: "2026-07-31"})
    end

    test "an empty description stays an empty string in the output" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_own_jira"))

      assert {:ok, %{worklogs: [_seed, from_jira, _empty]}} =
               invoke(:api_token, %{from: "2026-10-28", to: "2026-10-28"})

      assert %{tempo_worklog_id: 79_167, description: ""} = from_jira
      assert {:ok, json} = Jason.encode(from_jira)
      assert json =~ ~s("description":"")
    end

    # No recording leaves the description or the optional fields out, so
    # this is the recorded worklog without them.
    test "an absent description stays null in the output map, optional fields stay out" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklogs_own_jira",
          body: fn body ->
            update_in(body, ["results"], fn [seed, from_jira, empty] ->
              [seed, Map.drop(from_jira, ["description", "startTime", "billableSeconds"]), empty]
            end)
          end
        )
      end)

      assert {:ok, %{worklogs: [_seed, worklog, _empty]}} =
               invoke(:api_token, %{from: "2026-10-28", to: "2026-10-28"})

      assert %{tempo_worklog_id: 79_167, description: nil} = worklog
      refute Map.has_key?(worklog, :start_time)
      refute Map.has_key?(worklog, :billable_seconds)
      assert {:ok, json} = Jason.encode(worklog)
      assert json =~ ~s("description":null)
    end
  end

  describe "gates before HTTP" do
    setup do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, "worklogs_own")
      end)

      :ok
    end

    test "no input selects another account" do
      for extra <- [
            %{account_id: "account-2"},
            %{author_account_id: "account-2"},
            %{accountId: "account-2"},
            %{updated_from: "2026-10-30"}
          ] do
        assert {:error, %Error.ValidationError{reason: :input}} =
                 invoke(:api_token, Map.merge(@periods, extra))
      end

      refute_received :requested
    end

    test "a missing or invalid range fails validation" do
      for input <- [
            %{from: "2026-10-01"},
            %{to: "2026-10-31"},
            %{from: "2026-10-31", to: "2026-10-01"},
            %{from: "2026-10-01T00:00:00Z", to: "2026-10-31"},
            %{from: "2026-10-01", to: "31.10.2026"}
          ] do
        assert {:error, %Error.ValidationError{}} = invoke(:api_token, input)
      end

      refute_received :requested
    end

    test "an invalid range fails before an injected provider client is called" do
      context = context(:api_token)

      for {input, field} <- [
            {%{from: "2026-10-31", to: "2026-10-01"}, :to},
            {%{from: "2026-10-01", to: "31.10.2026"}, :to},
            {%{from: "yesterday", to: "2026-10-31"}, :from}
          ] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_date_range,
                  subject: ^field,
                  details: %{field: ^field}
                }} =
                 ListOwnWorklogs.run(input, %{
                   integration_context: context,
                   credential_lease: lease(context),
                   provider_client: RecordingClient
                 })
      end

      refute_received {:list_own_worklogs, _request, _opts}
    end

    test "a missing tempo.worklogs.read grant stops the call" do
      assert {:error,
              %Error.AuthError{reason: :missing_scopes, missing_scopes: ["tempo.worklogs.read"]}} =
               invoke(:api_token, @periods,
                 scopes: ["tempo.periods.read", "tempo.worklogs.write"]
               )

      refute_received :requested
    end

    test "an expired lease stops the call" do
      context = context(:api_token)
      expired = lease(context, expires_at: DateTime.add(DateTime.utc_now(), -1, :second))

      assert {:error, %Error.AuthError{}} =
               Connect.invoke(Tempo, @action, @periods,
                 context: context,
                 credential_lease: expired
               )

      refute_received :requested
    end

    test "a lease of another connection stops the call" do
      context = context(:api_token)
      other = context(:api_token, connection_id: "tempo_conn_other")

      assert {:error, %Error.AuthError{}} =
               Connect.invoke(Tempo, @action, @periods,
                 context: context,
                 credential_lease: lease(other)
               )

      refute_received :requested
    end

    test "a lease without the profile's token field stops the call" do
      context = context(:oauth2_user)
      lease = lease(context, fields: %{api_token: @api_token})

      assert {:error, %Error.AuthError{reason: :tempo_credentials_required}} =
               Connect.invoke(Tempo, @action, @periods, context: context, credential_lease: lease)

      refute_received :requested
    end

    test "a connection without subject.account_id stops the call" do
      context = context(:api_token, account_id: nil)

      assert {:error, %Error.AuthError{reason: :tempo_account_id_required}} =
               Connect.invoke(Tempo, @action, @periods,
                 context: context,
                 credential_lease: lease(context)
               )

      refute_received :requested
    end
  end

  describe "errors" do
    test "a failed later page returns no worklogs and no credentials" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case URI.decode_query(conn.query_string)["offset"] do
          "0" -> Fixture.respond(conn, "worklogs_own")
          "50" -> Fixture.respond(conn, "worklogs_own.2", status: 500)
        end
      end)

      assert {:error, %Error.ProviderError{provider: :tempo, reason: :server_error} = error} =
               invoke(:oauth2_user, @periods)

      for text <- [inspect(error), inspect(Error.to_map(error)), Exception.message(error)],
          secret <- [@api_token, @access_token, "JCL live"] do
        refute text =~ secret
      end
    end
  end

  defp expect_pages(names) do
    Req.Test.expect(__MODULE__, length(names), fn conn ->
      offset = String.to_integer(URI.decode_query(conn.query_string)["offset"])
      Fixture.respond(conn, Enum.at(names, div(offset, 50)))
    end)
  end

  defp recorded(name, id) do
    Enum.find(Fixture.recorded!(name)["body"]["results"], &(&1["tempoWorklogId"] == id))
  end

  defp invoke(profile, input, opts \\ []) do
    context = context(profile, Keyword.take(opts, [:scopes]))
    Connect.invoke(Tempo, @action, input, context: context, credential_lease: lease(context))
  end

  defp context(profile, opts \\ []) do
    connection =
      Connection.new!(%{
        id: Keyword.get(opts, :connection_id, "tempo_conn_1"),
        provider: :tempo,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: Keyword.get(opts, :account_id, @account)},
        status: :connected,
        scopes: Keyword.get(opts, :scopes, ["tempo.worklogs.read"]),
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
      Keyword.get_lazy(opts, :fields, fn ->
        case connection.profile do
          :api_token -> %{api_token: @api_token}
          :oauth2_user -> %{access_token: @access_token}
        end
      end)

    CredentialLease.from_connection!(connection, fields,
      expires_at:
        Keyword.get_lazy(opts, :expires_at, fn -> DateTime.add(DateTime.utc_now(), 60) end)
    )
  end
end
