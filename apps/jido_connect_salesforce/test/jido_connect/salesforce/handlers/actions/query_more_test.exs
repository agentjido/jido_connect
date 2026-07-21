defmodule Jido.Connect.Salesforce.Handlers.Actions.QueryMoreTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.QueryMore

  describe "run/2" do
    test "returns records and pagination on success" do
      records = [
        %{id: "0015g00000XYZaC", type: "Account", fields: %{"Name" => "Third Corp"}}
      ]

      pagination = %{total_size: 3, done: true}

      MockClient.stub(query_more: {:ok, %{items: records, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               QueryMore.run(
                 %{next_records_url: "/services/data/v60.0/query/01g5g00000QRS-2000"},
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
      assert result.pagination.total_size == 3
      assert result.pagination.done == true
    end

    test "returns paginated result with next page" do
      records = [
        %{id: "0015g00000XYZaC", type: "Account", fields: %{"Name" => "Third Corp"}}
      ]

      pagination = %{
        total_size: 3000,
        done: false,
        next_records_url: "/services/data/v60.0/query/01g5g00000QRS-4000"
      }

      MockClient.stub(query_more: {:ok, %{items: records, pagination: pagination}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, result} =
               QueryMore.run(
                 %{next_records_url: "/services/data/v60.0/query/01g5g00000QRS-2000"},
                 %{credentials: credentials}
               )

      assert result.pagination.done == false
      assert result.pagination.next_records_url == "/services/data/v60.0/query/01g5g00000QRS-4000"
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :salesforce, message: "Invalid session"}}

      MockClient.stub(query_more: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               QueryMore.run(
                 %{next_records_url: "/services/data/v60.0/query/invalid"},
                 %{credentials: credentials}
               )
    end
  end
end
