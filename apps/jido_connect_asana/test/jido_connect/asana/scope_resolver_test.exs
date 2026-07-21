defmodule Jido.Connect.Asana.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.ScopeResolver

  describe "required_scopes/3" do
    test "returns default scope for nil operation" do
      assert ScopeResolver.required_scopes(nil, %{}, %{}) == ["default"]
    end

    test "returns read scopes for task get" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.get"}, %{}, %{}) == [
               "default",
               "read"
             ]
    end

    test "returns read scopes for map with action_id" do
      assert ScopeResolver.required_scopes(%{action_id: "asana.task.get"}, %{}, %{}) == [
               "default",
               "read"
             ]
    end

    test "returns default scope for workspace list" do
      assert ScopeResolver.required_scopes(%{id: "asana.workspace.list"}, %{}, %{}) == [
               "default"
             ]
    end

    test "returns default scope for unknown operation" do
      assert ScopeResolver.required_scopes(%{id: "asana.unknown"}, %{}, %{}) == ["default"]
    end

    test "returns write scope for task create" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.create"}, %{}, %{}) == [
               "write"
             ]
    end

    test "returns write scope for task update" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.update"}, %{}, %{}) == [
               "write"
             ]
    end

    test "returns write scope for complete task" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.complete"}, %{}, %{}) == [
               "write"
             ]
    end

    test "returns write scope for story create" do
      assert ScopeResolver.required_scopes(%{id: "asana.story.create"}, %{}, %{}) == [
               "write"
             ]
    end

    test "returns write scope for add task project" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.add_project"}, %{}, %{}) == [
               "write"
             ]
    end
  end
end
