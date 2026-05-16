defmodule Jido.Connect.Salesforce.ClientTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client

  test "resolve returns injected client module" do
    assert Client.resolve(%{salesforce_client: MockClient}) == MockClient
  end

  test "resolve returns default client module when no injection" do
    assert Client.resolve(%{}) == Client
  end

  test "credential_token extracts access_token" do
    assert Client.credential_token(%{access_token: "my-token"}) == "my-token"
  end

  test "credential_token returns nil when no token present" do
    assert Client.credential_token(%{}) == nil
  end

  test "instance_url extracts from credentials" do
    assert Client.instance_url(%{instance_url: "https://myorg.my.salesforce.com"}) ==
             "https://myorg.my.salesforce.com"
  end

  test "instance_url falls back to default" do
    assert Client.instance_url(%{}) ==
             "https://login.salesforce.com"
  end
end
