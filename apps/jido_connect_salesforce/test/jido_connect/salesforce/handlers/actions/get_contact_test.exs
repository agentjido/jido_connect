defmodule Jido.Connect.Salesforce.Handlers.Actions.GetContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.GetContact

  describe "run/2" do
    test "returns contact on success" do
      contact = %{
        contact_id: "0035g00000ABCdE",
        first_name: "Bella",
        last_name: "Martinez",
        email: "bella@example.com"
      }

      MockClient.stub(get_contact: {:ok, contact})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{contact: result}} =
               GetContact.run(%{contact_id: "0035g00000ABCdE"}, %{credentials: credentials})

      assert result.contact_id == "0035g00000ABCdE"
      assert result.email == "bella@example.com"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "Not found"}}

      MockClient.stub(get_contact: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetContact.run(%{contact_id: "999"}, %{credentials: credentials})
    end
  end
end
