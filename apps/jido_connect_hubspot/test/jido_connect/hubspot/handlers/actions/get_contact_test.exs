defmodule Jido.Connect.HubSpot.Handlers.Actions.GetContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Actions.GetContact

  describe "run/2" do
    test "returns contact on success" do
      contact = Contact.new!(%{contact_id: "501", email: "bella@example.com"})
      MockClient.stub(get_contact: {:ok, contact})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{contact: result}} =
               GetContact.run(%{contact_id: "501"}, %{credentials: credentials})

      assert result.contact_id == "501"
      assert result.email == "bella@example.com"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Not found"}}

      MockClient.stub(get_contact: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetContact.run(%{contact_id: "999"}, %{credentials: credentials})
    end
  end
end
