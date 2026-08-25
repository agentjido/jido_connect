defmodule Jido.Connect.MCP.ExMCPClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect

  alias Jido.Connect.MCP.{
    Endpoint,
    EndpointLeaseManager,
    EndpointResolver,
    ExMCPClient,
    HostEndpoint
  }

  defmodule Server do
    use ExMCP.Server.Handler
    use ExMCP.Server.DSL, name: "jido-connect-test", version: "1.0.0"

    tool "echo", "Echo text" do
      param(:text, :string, required: true)

      run(fn %{text: text}, state ->
        {:ok, %{content: [%{type: "text", text: text}]}, state}
      end)
    end
  end

  test "uses one scoped ExMCP client for tool listing and calls" do
    {:ok, server} = start_supervised({Server, transport: :beam, protocol_mode: :legacy_only})

    assert {:ok, endpoint} =
             Endpoint.new("test", %{
               transport: {:beam, server: server},
               client_info: %{name: "jido-connect-test"}
             })

    assert {:ok, client} = ExMCPClient.start_client(endpoint)
    assert Process.alive?(client)

    assert {:ok, %{"tools" => [tool]}} = ExMCPClient.list_tools(client, timeout: 1_000)
    assert tool["name"] == "echo"

    assert {:ok, %{"content" => [%{"text" => "hello"}]}} =
             ExMCPClient.call_tool(client, "echo", %{"text" => "hello"}, timeout: 1_000)

    assert :ok = ExMCPClient.stop_client(client)
    refute Process.alive?(client)
  end

  test "protects connection and retry options from endpoint input" do
    assert {:ok, endpoint} =
             Endpoint.new("test", %{
               transport: {:stdio, command: "echo"},
               client_info: %{name: "jido-connect-test"},
               client_options: [retry_policy: [max_attempts: 3]]
             })

    assert {:error, {:protected_client_option, :retry_policy}} =
             ExMCPClient.client_options(endpoint)
  end

  test "protects retry options inside transport input" do
    assert {:ok, endpoint} =
             Endpoint.new("test", %{
               transport: {:stdio, command: "echo", retry_policy: [max_attempts: 3]},
               client_info: %{name: "jido-connect-test"}
             })

    assert {:error, {:protected_client_option, :retry_policy}} =
             ExMCPClient.client_options(endpoint)
  end

  test "starts and stops one connection-scoped client for a lease" do
    {:ok, server} = start_supervised({Server, transport: :beam, protocol_mode: :legacy_only})

    connection =
      Connect.Connection.new!(%{
        id: "scoped-exmcp-client",
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant-1",
        owner_type: :tenant,
        owner_id: "tenant-1",
        status: :connected,
        metadata: %{mcp_endpoint_id: "local", connection_revision: 1}
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{id: "user-1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(
        connection,
        %{
          mcp_endpoint: %{
            transport: {:beam, server: server},
            client_info: %{name: "jido-connect-scoped-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    assert {:ok, token} =
             EndpointResolver.resolve_lease("local", %{
               context: context,
               credential_lease: lease
             })

    assert token.endpoint_id == HostEndpoint.internal_id(connection)
    refute token.endpoint_id == "local"
    assert token.client_module == ExMCPClient
    assert is_pid(token.client_ref)
    assert Process.alive?(token.client_ref)

    assert :ok = EndpointLeaseManager.release(token)
    assert :ok = EndpointLeaseManager.force_stop(connection)
    refute Process.alive?(token.client_ref)
  end
end
