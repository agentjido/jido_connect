defmodule Jido.Connect.Salesforce.Actions.ReadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce

  test "read fragment declares get_contact action" do
    spec = Salesforce.integration()
    action_ids = Enum.map(spec.actions, & &1.id)

    assert "salesforce.contacts.contact.get" in action_ids
    assert "salesforce.contacts.contact.list" in action_ids
  end

  test "get_contact action has correct metadata" do
    spec = Salesforce.integration()
    action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.get"))

    assert action.resource == :contact
    assert action.verb == :get
    assert action.risk == :read
    assert action.data_classification == :personal_data
    assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.GetContact
  end

  test "list_contacts action has correct metadata" do
    spec = Salesforce.integration()
    action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.list"))

    assert action.resource == :contact
    assert action.verb == :list
    assert action.risk == :read
    assert action.data_classification == :personal_data
    assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.ListContacts
  end
end
