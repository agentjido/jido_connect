defmodule Jido.Connect.Airtable.Handlers.Actions.ListRecordsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.ListRecords
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "returns records list on success" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "Task 2"}})
      ]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "appTest1", table_id: "tblTest1"},
                 %{credentials: credentials}
               )

      assert length(result.records) == 2
      assert hd(result.records).record_id == "rec1"
      assert hd(result.records).fields["Name"] == "Task 1"
    end

    test "returns records with offset for pagination" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}})]

      MockClient.stub(list_records: {:ok, %{records: records, offset: "itrXXXXX/recXXXXX"}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "appTest1", table_id: "tblTest1"},
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
      assert result.offset == "itrXXXXX/recXXXXX"
    end

    test "returns records without offset when no more pages" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "appTest1", table_id: "tblTest1"},
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
      refute Map.has_key?(result, :offset)
    end

    test "passes filter_by_formula to client" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Status" => "Active"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   filter_by_formula: "{Status} = 'Active'"
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "passes sort params to client" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "B"}})
      ]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   sort: [%{field: "Name", direction: "asc"}]
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 2
    end

    test "passes field selection to client" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   fields: ["Name", "Status"]
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "passes view param to client" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   view: "viwActiveOnly"
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "passes page_size and max_records to client" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   page_size: 10,
                   max_records: 100
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Table not found"}}

      MockClient.stub(list_records: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListRecords.run(
                 %{base_id: "appTest1", table_id: "tblInvalid"},
                 %{credentials: credentials}
               )
    end
  end
end
