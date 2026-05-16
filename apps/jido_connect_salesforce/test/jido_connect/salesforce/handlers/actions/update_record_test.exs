defmodule Jido.Connect.Salesforce.Handlers.Actions.UpdateRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.UpdateRecord

  describe "run/2" do
    test "returns record_id and success on update" do
      MockClient.stub(update_record: {:ok, %{success: true}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{record_id: "0015g00000XYZaA", success: true}} =
               UpdateRecord.run(
                 %{
                   sobject_type: "Account",
                   record_id: "0015g00000XYZaA",
                   fields: %{"Name" => "Acme Corp Updated"}
                 },
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

      MockClient.stub(update_record: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateRecord.run(
                 %{sobject_type: "Account", record_id: "0015g00000XYZaA"},
                 %{credentials: credentials}
               )
    end
  end
end
