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

  test "maps safe stdio and HTTP endpoint options to ExMCP" do
    stdio =
      endpoint(
        {:stdio,
         command: "echo",
         args: ["hello"],
         cwd: "/tmp",
         env: %{TOKEN_NAME: "public-name", DISABLED: false}},
        client_options: [stream_idle_timeout: 500]
      )

    assert {:ok, stdio_opts} = ExMCPClient.client_options(stdio)
    assert stdio_opts[:transport] == :stdio
    assert stdio_opts[:command] == ["echo", "hello"]
    assert stdio_opts[:cd] == "/tmp"
    assert Enum.sort(stdio_opts[:env]) == [{"DISABLED", false}, {"TOKEN_NAME", "public-name"}]
    assert stdio_opts[:protocol_mode] == :legacy_only
    assert stdio_opts[:reconnect] == false
    assert stdio_opts[:retry_policy] == []

    http =
      endpoint(
        {:streamable_http,
         base_url: "https://mcp.example.test",
         mcp_path: "/tools",
         headers: [{"x-public-tenant", "tenant-1"}],
         enable_sse: false,
         finch_name: MyFinch},
        protocol_version: "2026-01-01"
      )

    assert {:ok, http_opts} = ExMCPClient.client_options(http)
    assert http_opts[:transport] == :http
    assert http_opts[:url] == "https://mcp.example.test"
    assert http_opts[:endpoint] == "/tools"
    assert http_opts[:headers] == [{"x-public-tenant", "tenant-1"}]
    assert http_opts[:use_sse] == false
    assert http_opts[:protocol_mode] == :modern_only
    refute Keyword.has_key?(http_opts, :finch_name)
  end

  test "rejects unsafe or invalid stdio endpoint options" do
    invalid_transports = [
      {:stdio, []},
      {:stdio, command: []},
      {:stdio, command: "echo", args: "bad"},
      {:stdio, command: ["echo", 1]},
      {:stdio, command: ["echo", <<0>>]},
      {:stdio, command: "echo", cwd: <<"/tmp", 0>>},
      {:stdio, command: "echo", cwd: 123},
      {:stdio, command: "echo", env: [{"BAD=NAME", "value"}]},
      {:stdio, command: "echo", env: [:bad]},
      {:stdio, command: "echo", env: 123},
      {:stdio, command: "echo", dns_timeout_ms: 0}
    ]

    for transport <- invalid_transports do
      assert {:error, {:invalid_transport_options, _field}} =
               transport |> endpoint() |> ExMCPClient.client_options()
    end
  end

  test "rejects unsafe or invalid HTTP and BEAM endpoint options" do
    invalid_http = [
      {:streamable_http, []},
      {:streamable_http, base_url: "file:///tmp/mcp"},
      {:streamable_http, base_url: "https://mcp.example.test/path"},
      {:streamable_http, base_url: "https://mcp.example.test?secret=value"},
      {:streamable_http, base_url: "https://user@mcp.example.test"},
      {:streamable_http, base_url: "https://mcp.example.test", mcp_path: "tools"},
      {:streamable_http, base_url: "https://mcp.example.test", headers: :bad},
      {:streamable_http, base_url: "https://mcp.example.test", headers: [bad: 1]},
      {:streamable_http,
       base_url: "https://mcp.example.test", headers: [{"x-name", "value"}], retry_safe: true}
    ]

    for transport <- invalid_http do
      assert {:error, error} = transport |> endpoint() |> ExMCPClient.client_options()
      assert elem(error, 0) in [:invalid_transport_options, :protected_client_option]
    end

    alive_server = spawn(fn -> Process.sleep(:infinity) end)

    assert {:ok, beam_opts} =
             endpoint({:beam, server: alive_server}) |> ExMCPClient.client_options()

    assert beam_opts[:transport] == :beam
    Process.exit(alive_server, :kill)

    dead_server = spawn(fn -> :ok end)
    ref = Process.monitor(dead_server)
    assert_receive {:DOWN, ^ref, :process, ^dead_server, _reason}

    assert {:error, {:invalid_transport_options, :server}} =
             endpoint({:beam, server: dead_server}) |> ExMCPClient.client_options()

    assert {:error, {:invalid_transport_options, :server}} =
             endpoint({:beam, server: :not_a_pid}) |> ExMCPClient.client_options()

    assert {:error, {:unsupported_transport, :sse, :ex_mcp}} =
             endpoint({:sse, []}) |> ExMCPClient.client_options()
  end

  test "returns safe errors for invalid request options and missing clients" do
    assert {:error, %{reason: :invalid_params, details: %{field: :options}}} =
             ExMCPClient.list_tools(:unused, %{timeout: 10})

    assert {:error, %{reason: :invalid_params, details: %{field: :options}}} =
             ExMCPClient.list_tools(:unused, timeout: 0)

    assert {:error, %{reason: :invalid_params, details: %{field: :options}}} =
             ExMCPClient.call_tool(:unused, "echo", %{}, timeout: -1)

    assert {:error, %{reason: :request_failed, details: %{}}} =
             ExMCPClient.list_tools(:missing_ex_mcp_client, timeout: 1)

    assert :ok = ExMCPClient.stop_client(self())
    assert :ok = ExMCPClient.stop_client(:not_a_process)
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

  defp endpoint(transport, opts \\ []) do
    %Endpoint{
      id: "test",
      transport: transport,
      client_info: %{"name" => "jido-connect-test"},
      protocol_version: Keyword.get(opts, :protocol_version, "2025-06-18"),
      capabilities: %{},
      timeouts: %{request_ms: 1_000},
      client_options: Keyword.get(opts, :client_options, [])
    }
  end
end
