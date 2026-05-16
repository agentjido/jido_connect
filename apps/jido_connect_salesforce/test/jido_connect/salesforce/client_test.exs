defmodule Jido.Connect.Salesforce.ClientTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client

  setup do
    {:module, Client} = Code.ensure_loaded(Client)
    :ok
  end

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

  test "delegates query to Objects module" do
    assert function_exported?(Client, :query, 2)
  end

  test "delegates get_record to Objects module" do
    assert function_exported?(Client, :get_record, 2)
  end

  test "delegates describe_object to Objects module" do
    assert function_exported?(Client, :describe_object, 2)
  end

  test "delegates list_recent to Objects module" do
    assert function_exported?(Client, :list_recent, 2)
  end

  test "delegates query_more to Objects module" do
    assert function_exported?(Client, :query_more, 2)
  end

  test "delegates create_record to Objects module" do
    assert function_exported?(Client, :create_record, 2)
  end

  test "delegates update_record to Objects module" do
    assert function_exported?(Client, :update_record, 2)
  end

  test "delegates update_contact to Contacts module" do
    assert function_exported?(Client, :update_contact, 2)
  end

  test "delegates create_lead to Leads module" do
    assert function_exported?(Client, :create_lead, 2)
  end

  test "delegates update_lead to Leads module" do
    assert function_exported?(Client, :update_lead, 2)
  end

  test "delegates create_task to Tasks module" do
    assert function_exported?(Client, :create_task, 2)
  end

  test "delegates update_task to Tasks module" do
    assert function_exported?(Client, :update_task, 2)
  end
end
