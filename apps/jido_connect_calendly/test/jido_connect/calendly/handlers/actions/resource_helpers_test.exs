defmodule Jido.Connect.Calendly.Handlers.Actions.ResourceHelpersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers
  alias Jido.Connect.Calendly.Client

  describe "fetch_client/1" do
    test "resolves injected client from credentials" do
      assert {:ok, MockClient} = ResourceHelpers.fetch_client(%{calendly_client: MockClient})
    end

    test "falls back to default Client module" do
      assert {:ok, Client} = ResourceHelpers.fetch_client(%{})
    end
  end

  describe "credential_token/1" do
    test "extracts api_key" do
      assert ResourceHelpers.credential_token(%{api_key: "my-key"}) == "my-key"
    end

    test "extracts access_token" do
      assert ResourceHelpers.credential_token(%{access_token: "my-token"}) == "my-token"
    end

    test "prefers api_key over access_token" do
      assert ResourceHelpers.credential_token(%{api_key: "key", access_token: "token"}) == "key"
    end

    test "returns nil when no token present" do
      assert ResourceHelpers.credential_token(%{}) == nil
    end
  end

  describe "public_map/1" do
    test "converts struct to map" do
      event_type =
        Jido.Connect.Calendly.EventType.new!(%{
          uri: "https://api.calendly.com/event_types/et1",
          name: "Test"
        })

      result = ResourceHelpers.public_map(event_type)
      assert is_map(result)
      assert result.uri == "https://api.calendly.com/event_types/et1"
      assert result.name == "Test"
      refute Map.has_key?(result, :__struct__)
    end

    test "converts list of structs" do
      structs = [
        Jido.Connect.Calendly.EventType.new!(%{uri: "https://api.calendly.com/event_types/et1"}),
        Jido.Connect.Calendly.EventType.new!(%{uri: "https://api.calendly.com/event_types/et2"})
      ]

      result = ResourceHelpers.public_map(structs)
      assert length(result) == 2
      assert is_map(hd(result))
    end

    test "passes through plain values" do
      assert ResourceHelpers.public_map("hello") == "hello"
      assert ResourceHelpers.public_map(42) == 42
    end
  end
end
