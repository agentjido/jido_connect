defmodule Jido.Connect.Notion.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion.ScopeResolver

  describe "required_scopes/3 — read operations" do
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
  end

  describe "required_scopes/3 — write operations" do
    test "create page requires insert_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.page.create"}, %{}, %{}) ==
               ["insert_content"]
    end

    test "update page requires update_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.page.update"}, %{}, %{}) ==
               ["update_content"]
    end

    test "append block children requires insert_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.block.append_children"}, %{}, %{}) ==
               ["insert_content"]
    end

    test "update block requires update_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.block.update"}, %{}, %{}) ==
               ["update_content"]
    end

    test "archive block requires update_content" do
      assert ScopeResolver.required_scopes(%{id: "notion.block.archive"}, %{}, %{}) ==
               ["update_content"]
    end

    test "create comment requires insert_comments" do
      assert ScopeResolver.required_scopes(%{id: "notion.comment.create"}, %{}, %{}) ==
               ["insert_comments"]
    end
  end

  describe "required_scopes/3 — fallbacks" do
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
