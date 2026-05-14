defmodule Jido.Connect.Google.Contacts.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Contacts action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Contacts,
      [
        action("google.contacts.person.list", :personal_data, :read, :none),
        action("google.contacts.person.get", :personal_data, :read, :none),
        action("google.contacts.person.search", :personal_data, :read, :none),
        action("google.contacts.person.batch_get", :personal_data, :read, :none),
        action("google.contacts.person.batch_create", :personal_data, :write, :required_for_ai),
        action("google.contacts.person.batch_update", :personal_data, :write, :required_for_ai),
        action("google.contacts.person.batch_delete", :personal_data, :destructive, :always),
        action("google.contacts.directory.list", :personal_data, :read, :none),
        action("google.contacts.directory.search", :personal_data, :read, :none),
        action("google.contacts.other.list", :personal_data, :read, :none),
        action("google.contacts.other.search", :personal_data, :read, :none),
        action("google.contacts.other.copy", :personal_data, :write, :required_for_ai),
        action("google.contacts.group.get", :personal_data, :read, :none),
        action("google.contacts.group.batch_get", :personal_data, :read, :none),
        action("google.contacts.group.delete", :personal_data, :destructive, :always),
        action("google.contacts.group.member.modify", :personal_data, :write, :required_for_ai),
        action("google.contacts.person.create", :personal_data, :write, :required_for_ai),
        action("google.contacts.person.update", :personal_data, :write, :required_for_ai),
        action("google.contacts.person.delete", :personal_data, :destructive, :always),
        action("google.contacts.group.list", :personal_data, :read, :none),
        action("google.contacts.group.create", :personal_data, :write, :required_for_ai),
        action("google.contacts.group.update", :personal_data, :write, :required_for_ai)
      ],
      [
        trigger("google.contacts.person.changed", :personal_data)
      ]
    )
  end

  defp action(id, classification, risk, confirmation) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation
    }
  end

  defp trigger(id, classification) do
    %{
      id: id,
      classification: classification
    }
  end
end
