defmodule Jido.Connect.MCP.EndpointResolverTest do
  use ExUnit.Case

  alias Jido.Connect.MCP.EndpointResolver

  describe "resolve/1 with config-sourced endpoints" do
    setup do
      original = Application.get_env(:jido_mcp, :endpoints, nil)
      Application.put_env(:jido_mcp, :endpoints, %{weather: %{transport: {:stdio, []}}})

      on_exit(fn ->
        if original do
          Application.put_env(:jido_mcp, :endpoints, original)
        else
          Application.delete_env(:jido_mcp, :endpoints)
        end
      end)

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

  describe "resolve/1 with empty config" do
    setup do
      original = Application.get_env(:jido_mcp, :endpoints, nil)
      Application.put_env(:jido_mcp, :endpoints, %{})

      on_exit(fn ->
        if original do
          Application.put_env(:jido_mcp, :endpoints, original)
        else
          Application.delete_env(:jido_mcp, :endpoints)
        end
      end)

      :ok
    end

    test "any endpoint returns unknown error" do
      assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_mcp_endpoint}} =
               EndpointResolver.resolve("anything")
    end
  end

  describe "resolve/1 with keyword-list endpoints" do
    setup do
      original = Application.get_env(:jido_mcp, :endpoints, nil)
      Application.put_env(:jido_mcp, :endpoints, fs: %{transport: {:stdio, []}})

      on_exit(fn ->
        if original do
          Application.put_env(:jido_mcp, :endpoints, original)
        else
          Application.delete_env(:jido_mcp, :endpoints)
        end
      end)

      :ok
    end

    test "resolves keyword-list endpoint by string" do
      assert {:ok, :fs} = EndpointResolver.resolve("fs")
    end
  end
end
