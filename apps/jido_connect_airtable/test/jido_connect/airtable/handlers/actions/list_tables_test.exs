defmodule Jido.Connect.Airtable.Handlers.Actions.ListTablesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.ListTables
  alias Jido.Connect.Airtable.Table

  describe "run/2" do
    test "returns tables list on success" do
      tables = [
        Table.new!(%{table_id: "tblTest1", name: "Tasks"}),
        Table.new!(%{table_id: "tblTest2", name: "People"})
      ]

      MockClient.stub(list_tables: {:ok, %{tables: tables}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "appTest1"}, %{credentials: credentials})

      assert length(result.tables) == 2
      assert hd(result.tables).table_id == "tblTest1"
      assert hd(result.tables).name == "Tasks"
    end

    test "returns tables with offset for pagination" do
      tables = [Table.new!(%{table_id: "tblTest1", name: "Tasks"})]

      MockClient.stub(list_tables: {:ok, %{tables: tables, offset: "itrXXXXX/recXXXXX"}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "appTest1"}, %{credentials: credentials})

      assert length(result.tables) == 1
      assert result.offset == "itrXXXXX/recXXXXX"
    end

    test "returns tables without offset when no more pages" do
      tables = [Table.new!(%{table_id: "tblTest1", name: "Tasks"})]

      MockClient.stub(list_tables: {:ok, %{tables: tables}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "appTest1"}, %{credentials: credentials})

      assert length(result.tables) == 1
      refute Map.has_key?(result, :offset)
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Base not found"}}

      MockClient.stub(list_tables: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListTables.run(%{base_id: "appInvalid"}, %{credentials: credentials})
    end
  end
end
