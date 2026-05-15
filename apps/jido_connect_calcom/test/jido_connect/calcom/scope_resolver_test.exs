defmodule Jido.Connect.Calcom.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calcom.ScopeResolver

  test "returns scopes based on operation" do
    assert ScopeResolver.required_scopes(%{id: "calcom.event_types.list"}, %{}, %{}) ==
             ["EVENT_TYPE_READ"]

    assert ScopeResolver.required_scopes(%{id: "calcom.bookings.list"}, %{}, %{}) ==
             ["BOOKING_READ"]

    assert ScopeResolver.required_scopes(%{id: "calcom.bookings.get"}, %{}, %{}) ==
             ["BOOKING_READ"]

    assert ScopeResolver.required_scopes(%{id: "calcom.bookings.cancel"}, %{}, %{}) ==
             ["BOOKING_WRITE"]

    assert ScopeResolver.required_scopes(%{id: "calcom.bookings.reschedule"}, %{}, %{}) ==
             ["BOOKING_WRITE"]

    assert ScopeResolver.required_scopes(%{id: "calcom.webhooks.create"}, %{}, %{}) ==
             ["WEBHOOK_WRITE"]

    assert ScopeResolver.required_scopes(%{id: "calcom.webhooks.list"}, %{}, %{}) ==
             ["WEBHOOK_READ"]

    assert ScopeResolver.required_scopes(%{id: "calcom.webhooks.delete"}, %{}, %{}) ==
             ["WEBHOOK_WRITE"]
  end

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "calcom.unknown.action"}, %{}, %{}) == []
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end
end
