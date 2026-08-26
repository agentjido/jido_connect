defmodule Jido.Connect.MCP.EndpointResolverTest do
  use ExUnit.Case

  alias Jido.Connect
  alias Jido.Connect.MCP.{EndpointLeaseManager, EndpointResolver, HostEndpoint}

  defmodule StaticClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(_client, _opts), do: {:ok, %{"tools" => []}}
    def call_tool(_client, _name, _arguments, _opts), do: {:ok, %{"content" => []}}
  end

  setup do
    previous = Application.get_env(:jido_connect, :mcp_clients)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:jido_connect, :mcp_clients),
        else: Application.put_env(:jido_connect, :mcp_clients, previous)
    end)

    :ok
  end

  describe "resolve/1 with static host clients" do
    setup do
      register_client!(:weather)

      :ok
    end

    test "resolves a known endpoint by binary name" do
      assert {:ok, :weather} = EndpointResolver.resolve("weather")
    end

    test "resolves a known endpoint by atom" do
      assert {:ok, :weather} = EndpointResolver.resolve(:weather)
    end

    test "resolves a binary with surrounding whitespace" do
      assert {:ok, :weather} = EndpointResolver.resolve("  weather  ")
    end

    test "returns validation error for unknown endpoint" do
      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("nonexistent")
    end

    test "returns validation error for empty string" do
      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("")
    end

    test "returns validation error for whitespace-only string" do
      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("   ")
    end

    test "error includes subject in details" do
      assert {:error, error} = EndpointResolver.resolve("missing")
      assert error.subject == "missing"
    end
  end

  describe "resolve/1 with an unknown endpoint" do
    test "any endpoint returns unknown error" do
      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("anything")
    end
  end

  describe "resolve/1 with another static host client" do
    setup do
      register_client!(:fs)

      :ok
    end

    test "resolves endpoint by string" do
      assert {:ok, :fs} = EndpointResolver.resolve("fs")
    end
  end

  describe "resolve/2 with host-owned endpoints" do
    test "isolates two connections that use the same public endpoint id" do
      {context_a, lease_a} = host_context("slack-a", "token-a")
      {context_b, lease_b} = host_context("slack-b", "token-b")

      internal_a = HostEndpoint.internal_id(context_a.connection)
      internal_b = HostEndpoint.internal_id(context_b.connection)
      on_exit(fn -> EndpointLeaseManager.force_stop(context_a.connection) end)
      on_exit(fn -> EndpointLeaseManager.force_stop(context_b.connection) end)

      assert {:ok, token_a} =
               EndpointResolver.resolve_lease("slack", %{
                 context: context_a,
                 credential_lease: lease_a
               })

      assert {:ok, token_b} =
               EndpointResolver.resolve_lease("slack", %{
                 context: context_b,
                 credential_lease: lease_b
               })

      assert token_a.endpoint_id == internal_a
      assert token_b.endpoint_id == internal_b
      assert token_a.client_ref == {:test_client, "slack-a", 1}
      assert token_b.client_ref == {:test_client, "slack-b", 1}
      refute internal_a == internal_b
      :ok = EndpointLeaseManager.release(token_a)
      :ok = EndpointLeaseManager.release(token_b)
    end

    test "replaces one connection endpoint when its credential material changes" do
      {context, lease_a} = host_context("slack-rotate", "token-a", credential_version: 1)
      {_context, lease_b} = host_context("slack-rotate", "token-b", credential_version: 2)
      internal_id = HostEndpoint.internal_id(context.connection)

      assert {:ok, old_endpoint_id} =
               EndpointResolver.resolve("slack", %{
                 context: context,
                 credential_lease: lease_a
               })

      assert old_endpoint_id == internal_id

      assert {:ok, new_endpoint_id} =
               EndpointResolver.resolve("slack", %{
                 context: context,
                 credential_lease: lease_b
               })

      refute old_endpoint_id == new_endpoint_id

      assert [%{endpoint_id: ^new_endpoint_id, generation: 2, active: 0}] =
               EndpointLeaseManager.ownership(context.connection)

      on_exit(fn -> EndpointLeaseManager.force_stop(context.connection) end)
    end

    test "rejects an endpoint id outside the selected connection" do
      {context, lease} = host_context("slack-bound", "token")

      assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_connection_mismatch}} =
               EndpointResolver.resolve("other", %{
                 context: context,
                 credential_lease: lease
               })
    end

    test "rejects an invalid supplied endpoint with a host-owned client reference" do
      {context, lease} = host_context("slack-invalid", "token")
      lease = put_in(lease.fields[:mcp_endpoint][:transport], {:sse, []})

      assert {:error, %Connect.Error.ConfigError{key: :mcp_endpoint}} =
               EndpointResolver.resolve_lease("slack", %{
                 context: context,
                 credential_lease: lease
               })
    end
  end

  defp register_client!(endpoint_id) do
    clients = Application.get_env(:jido_connect, :mcp_clients, %{})

    Application.put_env(
      :jido_connect,
      :mcp_clients,
      Map.put(clients, endpoint_id, {StaticClient, endpoint_id})
    )
  end

  defp host_context(connection_id, token, opts \\ []) do
    scopes = ["mcp:tools:list", "mcp:tools:call", "mcp:endpoint:slack", "mcp:tool:post_message"]

    connection =
      Connect.Connection.new!(%{
        id: connection_id,
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes,
        metadata: %{mcp_endpoint_id: "slack", connection_revision: 1}
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "persona_1", type: :agent},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(
        connection,
        %{
          mcp_client_module: StaticClient,
          mcp_client_ref:
            {:test_client, connection_id, Keyword.get(opts, :credential_version, 1)},
          mcp_endpoint: %{
            transport:
              {:streamable_http,
               [url: "https://mcp.slack.example/mcp", headers: [{"authorization", token}]]},
            client_info: %{name: "jido-connect-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: Keyword.get(opts, :credential_version, 1)}
      )

    {context, lease}
  end
end
