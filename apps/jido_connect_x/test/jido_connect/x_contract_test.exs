defmodule Jido.Connect.XContractTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.X

  @action_contract %{
    "x.account.get" => {:social_account, :get, :read, :none},
    "x.bookmark.list" => {:social_bookmark, :list, :read, :none},
    "x.post.list" => {:social_post, :list, :read, :none}
  }

  test "declares exactly the three reviewed X read actions and local profile" do
    spec = X.integration()

    assert spec.id == :x
    assert spec.package == :jido_connect_x
    assert spec.name == "X"
    assert spec.category == :social
    assert spec.triggers == []

    assert Map.new(spec.actions, fn action ->
             {action.id, {action.resource, action.verb, action.risk, action.confirmation}}
           end) == @action_contract

    assert Enum.all?(spec.actions, &(&1.provider_idempotency? == false))

    assert [%{id: :local_mcp, kind: :api_key, owner: :user} = profile] = spec.auth_profiles
    assert profile.default?
    assert profile.credential_fields == [:mcp_endpoint]
    assert profile.lease_fields == [:mcp_endpoint]
  end

  test "owns exact endpoint, tool bindings, and required tool schemas" do
    expected = %{
      "x.account.get" => "get_users_me",
      "x.bookmark.list" => "get_users_bookmarks",
      "x.post.list" => "get_users_posts"
    }

    assert Map.new(X.Contract.actions(), &{&1.id, &1.tool}) == expected
    assert X.Contract.endpoint() == "http://127.0.0.1:8000/mcp"
    assert X.Contract.endpoint_id() == "x"
    assert map_size(X.Contract.tool_schemas()) == 3

    for {tool, schema} <- X.Contract.tool_schemas() do
      assert schema["type"] == "object"
      assert X.Contract.tool_schema(tool) == schema
    end
  end

  test "publishes bounded snake-case inputs without transport or identity overrides" do
    actions = Map.new(X.integration().actions, &{&1.id, &1})

    assert fields(actions["x.account.get"]) == %{}

    bookmarks = fields(actions["x.bookmark.list"])
    assert bookmarks.max_results.default == 20
    assert bookmarks.max_results.minimum == 1
    assert bookmarks.max_results.maximum == 100
    assert bookmarks.pagination_token.max_length == 2_048

    posts = fields(actions["x.post.list"])
    assert posts.max_results.default == 5
    assert posts.max_results.minimum == 5
    assert posts.max_results.maximum == 100

    forbidden = [
      :endpoint_id,
      :tool_name,
      :action,
      :account,
      :account_id,
      :user_id,
      :id,
      :username,
      :expected_username
    ]

    refute Enum.any?(actions, fn {_id, action} ->
             Enum.any?(forbidden, &Map.has_key?(fields(action), &1))
           end)
  end

  test "publishes only one reviewed reader pack and no generic MCP action" do
    action_ids = X.integration().actions |> Enum.map(& &1.id) |> MapSet.new()

    assert action_ids == MapSet.new(Map.keys(@action_contract))
    refute MapSet.member?(action_ids, "mcp.tools.list")
    refute MapSet.member?(action_ids, "mcp.tools.call")
    refute MapSet.member?(action_ids, "mcp.tool.call")

    assert [reader] = X.catalog_packs()
    assert reader.id == :x_reader
    assert reader.filters == %{provider: :x}
    assert reader.allowed_tools == ["x.account.get", "x.bookmark.list", "x.post.list"]
    assert reader.metadata.risk == :read
  end

  test "registers generated modules and package discovery" do
    assert Application.get_env(:jido_connect_x, :jido_connect_providers) == [X]
    assert length(X.jido_action_modules()) == 3
    assert X.jido_sensor_modules() == []
    assert X.jido_plugin_module() == Jido.Connect.X.Plugin

    assert %Connect.Catalog.Manifest{id: :x, package: :jido_connect_x} =
             X.jido_connect_manifest()

    for module <- X.jido_action_modules() do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
      assert {:error, _error} = module.run(%{}, %{})
    end
  end

  defp fields(action), do: Map.new(action.input, &{&1.name, &1})
end
