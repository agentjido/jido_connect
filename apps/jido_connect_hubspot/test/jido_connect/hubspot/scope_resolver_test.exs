defmodule Jido.Connect.HubSpot.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.ScopeResolver

  test "returns empty scopes for unknown operations in scaffold" do
    assert ScopeResolver.required_scopes(%{id: "hubspot.contacts.list"}, %{}, %{}) == []
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end
end
