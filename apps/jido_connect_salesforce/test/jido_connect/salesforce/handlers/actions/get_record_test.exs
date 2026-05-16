defmodule Jido.Connect.Salesforce.Handlers.Actions.GetRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.GetRecord

  describe "run/2" do
    test "returns record on success" do
      record = %{
        id: "0015g00000XYZaA",
        type: "Account",
        fields: %{"Name" => "Acme Corp", "Industry" => "Technology"}
      }

      MockClient.stub(get_record: {:ok, record})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{record: result}} =
               GetRecord.run(
                 %{sobject_type: "Account", record_id: "0015g00000XYZaA"},
                 %{credentials: credentials}
               )

      assert result.id == "0015g00000XYZaA"
      assert result.type == "Account"
      assert result.fields["Name"] == "Acme Corp"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "Not found"}}

      MockClient.stub(get_record: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetRecord.run(
                 %{sobject_type: "Account", record_id: "999"},
                 %{credentials: credentials}
               )
    end
  end
end
