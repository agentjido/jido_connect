defmodule Jido.Connect.Salesforce.Handlers.Actions.ListRecentTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.ListRecent

  describe "run/2" do
    test "returns records and pagination on success" do
      records = [
        %{id: "0015g00000XYZaA", type: "Account", fields: %{"Name" => "Acme Corp"}},
        %{id: "0015g00000XYZaB", type: "Account", fields: %{"Name" => "Globex Inc"}}
      ]

      pagination = %{total_size: 2, done: true}

      MockClient.stub(list_recent: {:ok, %{items: records, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               ListRecent.run(%{sobject_type: "Account"}, %{credentials: credentials})

      assert length(result.records) == 2
      assert result.pagination.total_size == 2
    end

    test "passes fields and limit through" do
      records = [%{id: "0015g00000XYZaA", type: "Account", fields: %{"Name" => "Acme"}}]
      pagination = %{total_size: 1, done: true}

      MockClient.stub(list_recent: {:ok, %{items: records, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               ListRecent.run(
                 %{sobject_type: "Account", fields: ["Id", "Name"], limit: 5},
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "INVALID_TYPE"}}

      MockClient.stub(list_recent: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListRecent.run(%{sobject_type: "BadObject"}, %{credentials: credentials})
    end
  end
end
