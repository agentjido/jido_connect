defmodule Jido.Connect.MCP.EndpointResolverTest do
  use ExUnit.Case

  alias Jido.Connect
  alias Jido.Connect.MCP.{EndpointResolver, HostEndpoint}

  describe "resolve/1 with registered endpoints" do
    setup do
      register_endpoint!(:weather)
      on_exit(fn -> unregister_endpoint(:weather) end)

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
      unregister_endpoint(:anything)

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("anything")
    end
  end

  describe "resolve/1 with another registered endpoint" do
    setup do
      register_endpoint!(:fs)
      on_exit(fn -> unregister_endpoint(:fs) end)

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
      on_exit(fn -> unregister_endpoint(internal_a) end)
      on_exit(fn -> unregister_endpoint(internal_b) end)

      assert {:ok, ^internal_a} =
               EndpointResolver.resolve("slack", %{
                 context: context_a,
                 credential_lease: lease_a
               })

      assert {:ok, ^internal_b} =
               EndpointResolver.resolve("slack", %{
                 context: context_b,
                 credential_lease: lease_b
               })

      refute internal_a == internal_b

      assert {:ok, endpoint_a} = Jido.MCP.ClientPool.fetch_endpoint(internal_a)
      assert {:ok, endpoint_b} = Jido.MCP.ClientPool.fetch_endpoint(internal_b)
      assert endpoint_a.transport != endpoint_b.transport
    end

    test "replaces one connection endpoint when its credential material changes" do
      {context, lease_a} = host_context("slack-rotate", "token-a")
      {_context, lease_b} = host_context("slack-rotate", "token-b")
      internal_id = HostEndpoint.internal_id(context.connection)
      on_exit(fn -> unregister_endpoint(internal_id) end)

      assert {:ok, ^internal_id} =
               EndpointResolver.resolve("slack", %{
                 context: context,
                 credential_lease: lease_a
               })

      assert {:ok, endpoint_a} = Jido.MCP.ClientPool.fetch_endpoint(internal_id)

      assert {:ok, ^internal_id} =
               EndpointResolver.resolve("slack", %{
                 context: context,
                 credential_lease: lease_b
               })

      assert {:ok, endpoint_b} = Jido.MCP.ClientPool.fetch_endpoint(internal_id)
      refute endpoint_a == endpoint_b
    end

    test "rejects an endpoint id outside the selected connection" do
      {context, lease} = host_context("slack-bound", "token")

      assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_connection_mismatch}} =
               EndpointResolver.resolve("other", %{
                 context: context,
                 credential_lease: lease
               })
    end
  end

  defp register_endpoint!(endpoint_id) do
    {:ok, endpoint} =
      Jido.MCP.Endpoint.new(endpoint_id, %{
        transport: {:stdio, [command: "echo"]},
        client_info: %{name: "jido-connect-mcp-test"}
      })

    case Jido.MCP.register_endpoint(endpoint) do
      {:ok, _endpoint} -> :ok
      {:error, {:endpoint_already_registered, ^endpoint_id}} -> :ok
    end
  end

  defp unregister_endpoint(endpoint_id) do
    case Jido.MCP.unregister_endpoint(endpoint_id) do
      {:ok, _endpoint} -> :ok
      {:error, :unknown_endpoint} -> :ok
    end
  end

  defp host_context(connection_id, token) do
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
        metadata: %{mcp_endpoint_id: "slack"}
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
          mcp_endpoint: %{
            transport:
              {:streamable_http,
               [url: "https://mcp.slack.example/mcp", headers: [{"authorization", token}]]},
            client_info: %{name: "jido-connect-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    {context, lease}
  end
end
