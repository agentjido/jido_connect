defmodule Jido.Connect.Calendly.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.ScopeResolver

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "calendly.unknown.action"}, %{}, %{}) == []
  end

  test "returns empty scopes for operations without id" do
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "returns empty scopes for action_id key" do
    assert ScopeResolver.required_scopes(%{action_id: "calendly.some.action"}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end
end
