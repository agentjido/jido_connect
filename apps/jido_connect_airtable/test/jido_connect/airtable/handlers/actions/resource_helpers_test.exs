defmodule Jido.Connect.Airtable.Handlers.Actions.ResourceHelpersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  test "fetch_client resolves to injected client" do
    assert ResourceHelpers.fetch_client(%{airtable_client: FakeClient}) == {:ok, FakeClient}
  end

  test "fetch_client resolves to default Airtable client" do
    assert ResourceHelpers.fetch_client(%{}) == {:ok, Jido.Connect.Airtable.Client}
  end

  test "credential_token extracts api_key" do
    assert ResourceHelpers.credential_token(%{api_key: "pat-token"}) == "pat-token"
  end

  test "credential_token falls back to access_token" do
    assert ResourceHelpers.credential_token(%{access_token: "oauth-token"}) == "oauth-token"
  end

  test "credential_token prefers api_key over access_token" do
    assert ResourceHelpers.credential_token(%{api_key: "pat", access_token: "oauth"}) ==
             "pat"
  end

  test "public_map converts structs" do
    alias Jido.Connect.Airtable.Record

    record = Record.new!(%{record_id: "rec1", fields: %{"Name" => "Test"}})
    result = ResourceHelpers.public_map(record)

    assert is_map(result)
    assert result.record_id == "rec1"
    assert result.fields == %{"Name" => "Test"}
  end

  test "public_map converts lists" do
    assert ResourceHelpers.public_map([%{a: 1}, %{b: 2}]) == [%{a: 1}, %{b: 2}]
  end

  test "public_map passes through primitives" do
    assert ResourceHelpers.public_map("hello") == "hello"
    assert ResourceHelpers.public_map(42) == 42
  end

  test "public_map recurses nested maps" do
    assert ResourceHelpers.public_map(%{nested: %{deep: "value"}}) ==
             %{nested: %{deep: "value"}}
  end
end
