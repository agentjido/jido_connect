defmodule Jido.Connect.Salesforce.Handlers.Actions.DescribeObjectTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.DescribeObject

  describe "run/2" do
    test "returns metadata on success" do
      metadata = %{
        name: "Contact",
        label: "Contact",
        label_plural: "Contacts",
        key_prefix: "003",
        createable: true,
        updateable: true,
        fields: [
          %{"name" => "Id", "type" => "id"},
          %{"name" => "FirstName", "type" => "string"}
        ]
      }

      MockClient.stub(describe_object: {:ok, metadata})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{metadata: result}} =
               DescribeObject.run(%{sobject_type: "Contact"}, %{credentials: credentials})

      assert result.name == "Contact"
      assert result.label == "Contact"
      assert result.createable == true
      assert length(result.fields) == 2
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "NOT_FOUND"}}

      MockClient.stub(describe_object: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               DescribeObject.run(%{sobject_type: "InvalidObject"}, %{credentials: credentials})
    end
  end
end
