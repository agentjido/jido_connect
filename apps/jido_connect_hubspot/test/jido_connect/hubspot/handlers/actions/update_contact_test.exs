defmodule Jido.Connect.HubSpot.Handlers.Actions.UpdateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Actions.UpdateContact

  describe "run/2" do
    test "returns updated contact on success" do
      contact = Contact.new!(%{contact_id: "501", email: "updated@example.com"})
      MockClient.stub(update_contact: {:ok, contact})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{contact: result}} =
               UpdateContact.run(%{contact_id: "501", email: "updated@example.com"}, %{
                 credentials: credentials
               })

      assert result.contact_id == "501"
      assert result.email == "updated@example.com"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Not found"}}

      MockClient.stub(update_contact: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateContact.run(%{contact_id: "999"}, %{credentials: credentials})
    end
  end
end
