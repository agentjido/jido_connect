defmodule Jido.Connect.HubSpot.Handlers.Actions.ListContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Actions.ListContacts
  alias Jido.Connect.HubSpot.Pagination

  describe "run/2" do
    test "returns contacts list with pagination" do
      contacts = [
        Contact.new!(%{contact_id: "501", email: "bella@example.com"}),
        Contact.new!(%{contact_id: "502", email: "carlos@example.com"})
      ]

      pagination = Pagination.new!(%{after: "502", total: 42})
      MockClient.stub(list_contacts: {:ok, %{items: contacts, pagination: pagination}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListContacts.run(%{}, %{credentials: credentials})
      assert length(result.contacts) == 2
      assert hd(result.contacts).contact_id == "501"
      assert result.pagination.after == "502"
    end

    test "returns contacts list without pagination" do
      contacts = [Contact.new!(%{contact_id: "501"})]
      MockClient.stub(list_contacts: {:ok, %{items: contacts}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListContacts.run(%{}, %{credentials: credentials})
      assert length(result.contacts) == 1
      refute Map.has_key?(result, :pagination)
    end
  end
end
