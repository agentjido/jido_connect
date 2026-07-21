defmodule Jido.Connect.Salesforce.Handlers.Actions.CreateRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.CreateRecord

  describe "run/2" do
    test "returns record_id and success on create" do
      result = %{id: "0015g00000NEWID", success: true, errors: []}

      MockClient.stub(create_record: {:ok, result})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{record_id: "0015g00000NEWID", success: true}} =
               CreateRecord.run(
                 %{sobject_type: "Account", fields: %{"Name" => "Acme Corp"}},
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

      MockClient.stub(create_record: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateRecord.run(%{sobject_type: "Account"}, %{credentials: credentials})
    end
  end
end
