defmodule Jido.Connect.Salesforce.Handlers.Actions.CreateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.CreateContact

  describe "run/2" do
    test "returns contact_id and success on create" do
      result = %{id: "0035g00000NEWID", success: true, errors: []}

      MockClient.stub(create_contact: {:ok, result})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{contact_id: "0035g00000NEWID", success: true}} =
               CreateContact.run(
                 %{first_name: "Bella", last_name: "Martinez", email: "bella@example.com"},
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{
           provider: :salesforce,
           message: "Required field missing"
         }}

      MockClient.stub(create_contact: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateContact.run(%{}, %{credentials: credentials})
    end
  end
end
