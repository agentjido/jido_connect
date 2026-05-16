defmodule Jido.Connect.Salesforce.Handlers.Actions.UpdateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.UpdateContact

  describe "run/2" do
    test "returns contact_id and success on update" do
      MockClient.stub(update_contact: {:ok, %{success: true}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{contact_id: "0035g00000ABCdE", success: true}} =
               UpdateContact.run(
                 %{contact_id: "0035g00000ABCdE", last_name: "Martinez-Updated"},
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{
           provider: :salesforce,
           message: "INVALID_FIELD"
         }}

      MockClient.stub(update_contact: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateContact.run(
                 %{contact_id: "0035g00000ABCdE"},
                 %{credentials: credentials}
               )
    end
  end
end
