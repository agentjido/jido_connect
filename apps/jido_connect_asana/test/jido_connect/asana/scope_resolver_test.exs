defmodule Jido.Connect.Asana.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.ScopeResolver

  describe "required_scopes/3" do
    test "returns default scope for nil operation" do
      assert ScopeResolver.required_scopes(nil, %{}, %{}) == ["default"]
    end

    test "returns default scope for map with id" do
      assert ScopeResolver.required_scopes(%{id: "asana.task.get"}, %{}, %{}) == ["default"]
    end

    test "returns default scope for map with action_id" do
      assert ScopeResolver.required_scopes(%{action_id: "asana.task.get"}, %{}, %{}) == [
               "default"
             ]
    end

    test "returns default scope for unknown operation" do
      assert ScopeResolver.required_scopes(%{id: "asana.unknown"}, %{}, %{}) == ["default"]
    end
  end
end
