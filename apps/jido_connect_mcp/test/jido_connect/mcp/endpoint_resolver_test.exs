defmodule Jido.Connect.MCP.EndpointResolverTest do
  use ExUnit.Case

  alias Jido.Connect.MCP.EndpointResolver

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
end
