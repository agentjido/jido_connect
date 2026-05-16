defmodule Jido.Connect.Salesforce.Handlers.Actions.UpdateLeadTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.UpdateLead

  describe "run/2" do
    test "returns lead_id and success on update" do
      MockClient.stub(update_lead: {:ok, %{success: true}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{lead_id: "00Q5g00000ABCdE", success: true}} =
               UpdateLead.run(
                 %{lead_id: "00Q5g00000ABCdE", status: "Working - Contacted"},
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

      MockClient.stub(update_lead: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateLead.run(
                 %{lead_id: "00Q5g00000ABCdE"},
                 %{credentials: credentials}
               )
    end
  end
end
