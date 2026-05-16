defmodule Jido.Connect.Salesforce.Handlers.Actions.QueryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.Query

  describe "run/2" do
    test "returns records and pagination on success" do
      records = [
        %{id: "0015g00000XYZaA", type: "Account", fields: %{"Name" => "Acme Corp"}},
        %{id: "0015g00000XYZaB", type: "Account", fields: %{"Name" => "Globex Inc"}}
      ]

      pagination = %{total_size: 2, done: true}

      MockClient.stub(query: {:ok, %{items: records, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               Query.run(%{soql: "SELECT Id, Name FROM Account LIMIT 2"}, %{
                 credentials: credentials
               })

      assert length(result.records) == 2
      assert result.pagination.total_size == 2
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "MALFORMED_QUERY"}}

      MockClient.stub(query: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               Query.run(%{soql: "INVALID"}, %{credentials: credentials})
    end
  end
end
