defmodule Jido.Connect.HubSpot.Handlers.Actions.SearchContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Actions.SearchContacts
  alias Jido.Connect.HubSpot.Pagination

  describe "run/2" do
    test "returns search results with pagination" do
      contacts = [Contact.new!(%{contact_id: "501", email: "bella@example.com"})]
      pagination = Pagination.new!(%{total: 1})
      MockClient.stub(search_contacts: {:ok, %{items: contacts, pagination: pagination}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               SearchContacts.run(%{query: "bella"}, %{credentials: credentials})

      assert length(result.contacts) == 1
      assert hd(result.contacts).contact_id == "501"
    end

    test "returns empty results" do
      MockClient.stub(search_contacts: {:ok, %{items: []}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               SearchContacts.run(%{query: "nonexistent"}, %{credentials: credentials})

      assert result.contacts == []
    end
  end
end
