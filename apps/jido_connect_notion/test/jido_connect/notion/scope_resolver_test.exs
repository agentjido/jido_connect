defmodule Jido.Connect.Notion.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion.ScopeResolver

  describe "required_scopes/3" do
    test "search requires read_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.search"}, %{}, %{}) == ["read_content"]
    end

    test "get page requires read_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.page.get"}, %{}, %{}) ==
               ["read_content"]
    end

    test "get database requires read_content and read_databases" do
      scopes = ScopeResolver.required_scopes(%{id: "notion.database.get"}, %{}, %{})
      assert "read_content" in scopes
      assert "read_databases" in scopes
    end

    test "query database requires read_content and read_databases" do
      scopes = ScopeResolver.required_scopes(%{id: "notion.database.query"}, %{}, %{})
      assert "read_content" in scopes
      assert "read_databases" in scopes
    end

    test "retrieve block requires read_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.block.get"}, %{}, %{}) ==
               ["read_content"]
    end

    test "list block children requires read_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.block.list_children"}, %{}, %{}) ==
               ["read_content"]
    end

    test "list comments requires read_comments" do
      assert ScopeResolver.required_scopes(%{id: "notion.comment.list"}, %{}, %{}) ==
               ["read_comments"]
    end

    test "unknown operation defaults to read_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.unknown"}, %{}, %{}) ==
               ["read_content"]
    end

    test "nil operation defaults to read_content" do
      assert ScopeResolver.required_scopes(nil, %{}, %{}) == ["read_content"]
    end

    test "accepts action_id key" do
      assert ScopeResolver.required_scopes(%{action_id: "notion.search"}, %{}, %{}) ==
               ["read_content"]
    end

    test "accepts map with id key" do
      assert ScopeResolver.required_scopes(%{"id" => "notion.search"}, %{}, %{}) ==
               ["read_content"]
    end
  end
end
