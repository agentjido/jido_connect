defmodule Jido.Connect.Salesforce.Handlers.Actions.ListContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.ListContacts

  describe "run/2" do
    test "returns contacts and pagination on success" do
      contacts = [
        %{contact_id: "0035g00000ABCdE", first_name: "Bella", last_name: "Martinez"},
        %{contact_id: "0035g00000XYZaA", first_name: "Alice", last_name: "Johnson"}
      ]

      pagination = %{total_size: 2, done: true}

      MockClient.stub(list_contacts: {:ok, %{items: contacts, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               ListContacts.run(%{}, %{credentials: credentials})

      assert length(result.contacts) == 2
      assert result.pagination.total_size == 2
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "Unauthorized"}}

      MockClient.stub(list_contacts: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListContacts.run(%{}, %{credentials: credentials})
    end
  end
end
