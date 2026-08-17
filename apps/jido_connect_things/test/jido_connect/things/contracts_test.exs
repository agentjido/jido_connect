defmodule Jido.Connect.Things.ContractsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}

  alias Jido.Connect.Things.{Client, Input, ReadAdapter}
  alias Jido.Connect.Things.Client.Response

  defmodule Adapter do
    @behaviour ReadAdapter

    @impl true
    def list_open_inbox(connection_id, limit) do
      {:ok, %{connection_id: connection_id, limit: limit}}
    end

    @impl true
    def get_todo(_connection_id, _id, _provider_head) do
      raise "adapter detail must not cross the boundary"
    end
  end

  test "normalizes valid account, history, and page responses" do
    assert {:ok, account} =
             Response.account(
               {:ok,
                %{
                  status: 200,
                  body:
                    Jason.encode!(%{
                      "email" => "user@example.com",
                      "history-key" => "history-A",
                      "status" => "SYAccountStatusActive"
                    })
                }}
             )

    assert account.email == "user@example.com"
    assert account.history_key == "history-A"

    assert {:ok, history} =
             Response.history(
               {:ok,
                %{
                  status: 200,
                  body: %{
                    "latest-server-index" => "12",
                    "latest-schema-version" => "301"
                  }
                }},
               "history-A"
             )

    assert history.head == 12
    assert history.schema == 301
    assert {:ok, %{"items" => []}} = Response.page({:ok, %{status: 200, body: %{}}})
  end

  test "normalizes rejected, malformed, and failed responses without raw details" do
    assert {:error, %Error.AuthError{reason: :credential_rejected}} =
             Response.account({:ok, %{status: 401}})

    assert {:error, %Error.ProviderError{reason: :invalid_account_response}} =
             Response.account({:ok, %{status: 200, body: %{}}})

    assert {:error, %Error.ProviderError{reason: :invalid_history_response}} =
             Response.history(
               {:ok,
                %{
                  status: 200,
                  body: %{"latest-server-index" => -1, "latest-schema-version" => 301}
                }},
               "history-A"
             )

    assert {:error, %Error.ProviderError{reason: :history_page_failed, status: 503}} =
             Response.page({:ok, %{status: 503, body: "unavailable"}})

    assert {:error, %Error.ProviderError{reason: :history_page_failed} = error} =
             Response.page({:error, %{message: "secret-password", password: "secret-password"}})

    refute inspect(error) =~ "secret-password"

    assert {:error, %Error.ProviderError{reason: :invalid_history_page}} =
             Response.page({:ok, %{status: 200, body: ~s({"items":"invalid"})}})
  end

  test "strict write input accepts only the selected create and update fields" do
    assert {:ok, %{title: "Create", notes: "Note"}} =
             Input.parse("things.todo.create", %{"title" => "Create", "notes" => "Note"})

    assert {:ok, %{notes: "Changed", expected_modified_at: expected}} =
             Input.parse("things.todo.update", %{
               "id" => "VJ1edXTP9q3PmFDUuy8EQh",
               "expected_modified_at" => "2026-08-17T12:00:00Z",
               "notes" => "Changed"
             })

    assert expected == "2026-08-17T12:00:00Z"

    assert {:error, %Error.ValidationError{reason: :unknown_field}} =
             Input.parse("things.todo.create", %{title: "Create", project: "unsafe"})

    assert {:error, %Error.ValidationError{reason: :duplicate_field}} =
             Input.parse("things.todo.create", %{"title" => "Other", title: "Create"})

    assert {:error, %Error.ValidationError{reason: :invalid_datetime}} =
             Input.parse("things.todo.update", %{
               id: "VJ1edXTP9q3PmFDUuy8EQh",
               expected_modified_at: "not-a-date",
               title: "Changed"
             })

    assert {:error, %Error.ValidationError{reason: :invalid_input}} =
             Input.parse("things.todo.create", :invalid)
  end

  test "read adapter functions and modules keep host storage behind a narrow boundary" do
    assert {:ok, %{connection_id: "connection-A", limit: 25}} =
             ReadAdapter.list(Adapter, "connection-A", 25)

    assert {:ok, %{todos: []}} =
             ReadAdapter.list(
               fn "connection-A", 25 -> {:ok, %{todos: []}} end,
               "connection-A",
               25
             )

    assert {:error, %Error.ProviderError{reason: :read_adapter_failed} = error} =
             ReadAdapter.get(Adapter, "connection-A", "task-A", 1)

    refute inspect(error) =~ "adapter detail"

    assert {:error, %Error.ProviderError{reason: :read_adapter_failed}} =
             ReadAdapter.list(fn _connection_id, _limit -> :invalid end, "connection-A", 25)
  end

  test "client construction binds the connection account and lease" do
    {context, lease} = runtime_contract()

    assert {:ok, client} = Client.from_runtime(context, lease, transport: &ok_transport/3)
    assert client.transport_injected?

    mismatched_lease = %{lease | fields: %{email: "other@example.com", password: "password"}}

    assert {:error, %Error.AuthError{reason: :connection_account_mismatch}} =
             Client.from_runtime(context, mismatched_lease, transport: &ok_transport/3)

    newline_lease = %{lease | fields: %{email: "user@example.com", password: "bad\npassword"}}

    assert {:error, %Error.AuthError{reason: :invalid_lease_credential}} =
             Client.from_runtime(context, newline_lease, transport: &ok_transport/3)

    assert {:error, %Error.ConfigError{}} =
             Client.from_runtime(context, lease, transport: :not_a_transport)
  end

  test "client request failures do not expose raised transport details" do
    {context, lease} = runtime_contract()

    raising_transport = fn _method, _url, _opts ->
      raise "secret-password"
    end

    assert {:ok, client} = Client.from_runtime(context, lease, transport: raising_transport)
    assert {:error, result} = Client.request(client, :get, "/test", headers: [])
    assert result == %{kind: :transport_exception}
    refute inspect(result) =~ "secret-password"
  end

  test "list can use a host adapter without a provider request" do
    {context, lease} = runtime_contract()

    adapter = fn "connection-A", 2 ->
      {:ok,
       %{
         todos: [%{id: "task-A", title: "Projected"}],
         freshness: %{source: "host", provider_head: 9}
       }}
    end

    assert {:ok, result} =
             Jido.Connect.Things.invoke("things.todo.list", %{limit: 2},
               context: context,
               credential_lease: lease,
               read_adapter: adapter
             )

    assert result.count == 1
    assert result.freshness["provider_head"] == 9
  end

  defp runtime_contract do
    connection =
      Connection.new!(%{
        id: "connection-A",
        provider: :things,
        profile: :things_cloud_password,
        tenant_id: "tenant-1",
        owner_type: :app_user,
        owner_id: "user-1",
        subject: %{email: "user@example.com"},
        status: :connected,
        credential_ref: "credential-A",
        scopes: [],
        metadata: %{endpoint: Client.production_endpoint()}
      })

    context =
      Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{type: :human, id: "user-1"},
        connection: connection,
        claims: %{},
        metadata: %{}
      })

    lease =
      CredentialLease.from_connection!(
        connection,
        %{email: "user@example.com", password: "password"},
        expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second)
      )

    {context, lease}
  end

  defp ok_transport(_method, _url, _opts), do: {:ok, %{status: 200, body: %{}}}
end
