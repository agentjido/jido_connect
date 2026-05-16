defmodule Jido.Connect.Airtable.Client.ParamsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.ListRecords
  alias Jido.Connect.Airtable.Record

  describe "filtering params contract" do
    test "filter_by_formula is accepted by handler" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Status" => "Active"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   filter_by_formula: "{Status} = 'Active'"
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "sort params are accepted by handler" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "B"}})
      ]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   sort: [%{field: "Name", direction: "asc"}]
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 2
    end

    test "multi-field sort is accepted by handler" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   sort: [
                     %{field: "Priority", direction: "desc"},
                     %{field: "Name", direction: "asc"}
                   ]
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "fields selection is accepted by handler" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   fields: ["Name", "Status"]
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "view param is accepted by handler" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   view: "viwActiveOnly"
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
    end

    test "combined filter, sort, fields, and pagination are accepted" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records, offset: "itrNext/recNext"}})

      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{
                   base_id: "app1",
                   table_id: "tbl1",
                   filter_by_formula: "{Status} = 'Active'",
                   sort: [%{field: "Name", direction: "asc"}],
                   fields: ["Name"],
                   view: "viwActive",
                   page_size: 10,
                   max_records: 100,
                   offset: "itrPrev/recPrev"
                 },
                 %{credentials: credentials}
               )

      assert length(result.records) == 1
      assert result.offset == "itrNext/recNext"
    end
  end
end
