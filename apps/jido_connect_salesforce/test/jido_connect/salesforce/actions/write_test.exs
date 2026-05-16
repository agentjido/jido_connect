defmodule Jido.Connect.Salesforce.Actions.WriteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce

  test "write fragment declares create_contact action" do
    spec = Salesforce.integration()
    action_ids = Enum.map(spec.actions, & &1.id)

    assert "salesforce.contacts.contact.create" in action_ids
  end

  test "create_contact action has correct metadata" do
    spec = Salesforce.integration()
    action = Enum.find(spec.actions, &(&1.id == "salesforce.contacts.contact.create"))

    assert action.resource == :contact
    assert action.verb == :create
    assert action.risk == :write
    assert action.data_classification == :personal_data
    assert action.handler == Jido.Connect.Salesforce.Handlers.Actions.CreateContact
    assert action.confirmation == :required_for_ai
  end
end
