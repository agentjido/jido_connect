defmodule Jido.Connect.HubSpot.ClientTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Client

  test "resolves to injected client when present in credentials" do
    assert Client.resolve(%{hubspot_client: FakeClient}) == FakeClient
  end

  test "resolves to default client when no injection" do
    assert Client.resolve(%{}) == Client
  end

  test "extracts api_key from credentials" do
    assert Client.credential_token(%{api_key: "pat-token"}) == "pat-token"
  end

  test "extracts access_token from credentials as fallback" do
    assert Client.credential_token(%{access_token: "oauth-token"}) == "oauth-token"
  end

  test "prefers api_key over access_token" do
    assert Client.credential_token(%{api_key: "pat-token", access_token: "oauth-token"}) ==
             "pat-token"
  end
end
