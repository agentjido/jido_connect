defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Actions.CreateContact

  describe "run/2" do
    test "returns contact on success" do
      contact = Contact.new!(%{contact_id: "501", email: "new@example.com"})
      MockClient.stub(create_contact: {:ok, contact})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{contact: result}} =
               CreateContact.run(%{email: "new@example.com"}, %{credentials: credentials})

      assert result.contact_id == "501"
      assert result.email == "new@example.com"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Bad request"}}

      MockClient.stub(create_contact: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateContact.run(%{email: "bad"}, %{credentials: credentials})
    end
  end
end
