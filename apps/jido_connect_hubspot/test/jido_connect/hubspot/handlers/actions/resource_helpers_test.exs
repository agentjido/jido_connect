defmodule Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpers

  test "fetch_client resolves to injected client" do
    assert ResourceHelpers.fetch_client(%{hubspot_client: FakeClient}) == {:ok, FakeClient}
  end

  test "fetch_client resolves to default HubSpot client" do
    assert ResourceHelpers.fetch_client(%{}) == {:ok, Jido.Connect.HubSpot.Client}
  end

  test "credential_token extracts api_key" do
    assert ResourceHelpers.credential_token(%{api_key: "pat-token"}) == "pat-token"
  end

  test "credential_token falls back to access_token" do
    assert ResourceHelpers.credential_token(%{access_token: "oauth-token"}) == "oauth-token"
  end

  test "public_map converts structs" do
    assert ResourceHelpers.public_map(%{foo: "bar"}) == %{foo: "bar"}
  end

  test "public_map converts lists" do
    assert ResourceHelpers.public_map([%{a: 1}, %{b: 2}]) == [%{a: 1}, %{b: 2}]
  end

  test "public_map passes through primitives" do
    assert ResourceHelpers.public_map("hello") == "hello"
    assert ResourceHelpers.public_map(42) == 42
  end

  test "public_map recurses nested maps" do
    assert ResourceHelpers.public_map(%{nested: %{deep: "value"}}) == %{nested: %{deep: "value"}}
  end
end
