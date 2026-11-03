defmodule Jido.Connect.Tempo.ListAccountsForProjectActionTest do
  use ExUnit.Case, async: false

  # `tempo.account.list_for_project` through the runtime and through the
  # generated Jido action, against the reads that the live test of the
  # account candidates recorded for the test project 10882: the links on
  # `accounts_for_project` and the details of accounts 26 to 29 on `.2` to
  # `.5`. The site's global accounts outside the test data were left out at
  # record time.

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Actions.ListAccountsForProject
  alias Jido.Connect.Tempo.Fixture

  @action "tempo.account.list_for_project"
  @api_token "tempo-api-token-273-secret"
  @access_token "tempo-oauth-token-273-secret"
  @input %{project_id: 10_882}
  @details %{
    "26" => "accounts_for_project.2",
    "27" => "accounts_for_project.3",
    "28" => "accounts_for_project.4",
    "29" => "accounts_for_project.5"
  }

  defmodule RecordingClient do
    @moduledoc false

    # A provider client that reports its call and returns no accounts.
    def list_accounts_for_project(request, project_id, opts) do
      send(self(), {:list_accounts_for_project, request, project_id, opts})
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
    test "returns the project's candidates as plain maps with their link evidence" do
      serve()

      assert {:ok, %{project_id: 10_882, accounts: [project, secondary, closed, global]} = result} =
               invoke(:api_token, @input)

      refute is_struct(project)

      assert project == %{
               id: 26,
               key: "JCL-PROJECT",
               name: "JCL live: project account",
               status: "OPEN",
               global: false,
               self: "https://api.tempo.io/4/accounts/26",
               links: [%{id: 24, default: true, scope_type: "PROJECT", scope_id: 10_882}]
             }

      assert %{key: "JCL-SECONDARY", links: [%{id: 25, default: false}]} = secondary
      assert %{key: "JCL-CLOSED", status: "CLOSED"} = closed
      assert %{key: "JCL-GLOBAL", global: true, links: [%{id: 0, default: false}]} = global

      assert {:ok, json} = Jason.encode(result)
      refute json =~ "lead"
    end

    test "the generated action reads with the OAuth profile" do
      serve()
      context = context(:oauth2_user)

      assert {:ok, %{project_id: 10_882, accounts: [_, _, _, _]}} =
               ListAccountsForProject.run(@input, %{
                 integration_context: context,
                 credential_lease: lease(context)
               })
    end

    test "the project ID reaches the provider client seam unchanged" do
      context = context(:api_token)

      assert {:ok, %{project_id: 10_010, accounts: []}} =
               ListAccountsForProject.run(%{project_id: 10_010}, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: RecordingClient
               })

      assert_received {:list_accounts_for_project, request, 10_010, []}
      assert request.connection_id == "tempo_conn_1"
    end

    test "a failed account read fails the action without any candidate" do
      serve(%{"28" => "account_not_found"})

      assert {:error, %Error.ProviderError{reason: :not_found, status: 404} = error} =
               invoke(:api_token, @input)

      for text <- [inspect(error), inspect(Error.to_map(error))] do
        refute text =~ @api_token
        refute text =~ "JCL-PROJECT"
      end
    end
  end

  describe "gates before HTTP" do
    setup do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, "accounts_for_project")
      end)

      :ok
    end

    # Jira returns a project ID as a string such as "10882"; the host
    # converts it, the action does not.
    test "a missing, non-positive or non-integer project ID fails validation" do
      for input <- [
            %{},
            %{project_id: 0},
            %{project_id: -10_882},
            %{project_id: 1.5},
            %{project_id: "JCL"},
            %{project_id: "10882"},
            %{project_id: 10_882, include_global_accounts: false},
            %{project_id: 10_882, account_id: 26}
          ] do
        assert {:error, %Error.ValidationError{}} = invoke(:api_token, input)
      end

      refute_received :requested
    end

    test "a missing tempo.accounts.read grant stops the call" do
      assert {:error,
              %Error.AuthError{reason: :missing_scopes, missing_scopes: ["tempo.accounts.read"]}} =
               invoke(:api_token, @input,
                 scopes: ["tempo.worklogs.read", "tempo.worklogs.write", "tempo.periods.read"]
               )

      refute_received :requested
    end

    test "an expired lease or a lease of another connection stops the call" do
      context = context(:api_token)
      other = context(:api_token, connection_id: "tempo_conn_other")
      expired = lease(context, expires_at: DateTime.add(DateTime.utc_now(), -1, :second))

      for lease <- [expired, lease(other)] do
        assert {:error, %Error.AuthError{}} =
                 Connect.invoke(Tempo, @action, @input, context: context, credential_lease: lease)
      end

      refute_received :requested
    end

    test "a lease without the profile's token field stops the call" do
      context = context(:oauth2_user)
      lease = lease(context, fields: %{api_token: @api_token})

      assert {:error, %Error.AuthError{reason: :tempo_credentials_required}} =
               Connect.invoke(Tempo, @action, @input, context: context, credential_lease: lease)

      refute_received :requested
    end
  end

  # Answers the links read and each account read with the recording;
  # `replace` maps an account ID to another recorded answer.
  defp serve(replace \\ %{}) do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/4/account-links/project/10882" ->
          Fixture.respond(conn, "accounts_for_project")

        "/4/accounts/" <> id ->
          Fixture.respond(conn, Map.get(replace, id, Map.fetch!(@details, id)))
      end
    end)
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
        subject: %{account_id: "account-1"},
        status: :connected,
        scopes: Keyword.get(opts, :scopes, ["tempo.accounts.read"]),
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
