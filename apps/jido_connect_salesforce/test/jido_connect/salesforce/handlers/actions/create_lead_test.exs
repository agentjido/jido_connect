defmodule Jido.Connect.Salesforce.Handlers.Actions.CreateLeadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.CreateLead

  describe "run/2" do
    test "returns lead_id and success on create" do
      result = %{id: "00Q5g00000NEWID", success: true, errors: []}

      MockClient.stub(create_lead: {:ok, result})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{lead_id: "00Q5g00000NEWID", success: true}} =
               CreateLead.run(
                 %{last_name: "Chen", company: "Acme Corp"},
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

      MockClient.stub(create_lead: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateLead.run(%{}, %{credentials: credentials})
    end
  end
end
