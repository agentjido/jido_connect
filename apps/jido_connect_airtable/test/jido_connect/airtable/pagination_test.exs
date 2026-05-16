defmodule Jido.Connect.Airtable.PaginationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Client.Response
  alias Jido.Connect.Airtable.Handlers.Actions.ListRecords
  alias Jido.Connect.Airtable.Handlers.Actions.ListBases
  alias Jido.Connect.Airtable.Handlers.Actions.ListTables
  alias Jido.Connect.Airtable.{Base, Record, Table}

  describe "list_bases pagination" do
    test "passes offset through from handler to client" do
      bases = [Base.new!(%{base_id: "app1", name: "Base 1"})]

      MockClient.stub(list_bases: {:ok, bases})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListBases.run(%{offset: "itrXXXXX/recXXXXX"}, %{credentials: credentials})

      assert length(result.bases) == 1
    end

    test "response handles base list without offset" do
      payload = %{
        "bases" => [
          %{"id" => "app1", "name" => "Base 1"}
        ]
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, bases} = Response.handle_list_bases_response(response)
      assert length(bases) == 1
    end

    test "response handles base list with offset" do
      payload = fixture!("base_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, bases} = Response.handle_list_bases_response(response)
      assert length(bases) == 2
    end
  end

  describe "list_tables pagination" do
    test "handler returns offset for next page" do
      tables = [Table.new!(%{table_id: "tbl1", name: "Table 1"})]

      MockClient.stub(list_tables: {:ok, %{tables: tables, offset: "itrNext/recNext"}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "app1"}, %{credentials: credentials})

      assert result.offset == "itrNext/recNext"
      assert length(result.tables) == 1
    end

    test "handler omits offset when no more pages" do
      tables = [Table.new!(%{table_id: "tbl1", name: "Table 1"})]

      MockClient.stub(list_tables: {:ok, %{tables: tables}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "app1"}, %{credentials: credentials})

      refute Map.has_key?(result, :offset)
    end

    test "response handles table list with offset" do
      payload = fixture!("table_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_tables_response(response)
      assert result.offset == "itrYYYYYYYYYYYY/recYYYYYYYYYYYY"
    end

    test "response handles table list without offset" do
      payload = %{
        "tables" => [
          %{"id" => "tbl1", "name" => "Table 1", "primaryFieldId" => "fld1"}
        ]
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_tables_response(response)
      refute Map.has_key?(result, :offset)
    end
  end

  describe "list_records pagination" do
    test "handler returns offset for next page" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records, offset: "itrNext/recNext"}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "app1", table_id: "tbl1"},
                 %{credentials: credentials}
               )

      assert result.offset == "itrNext/recNext"
      assert length(result.records) == 1
    end

    test "handler omits offset when no more pages" do
      records = [Record.new!(%{record_id: "rec1", fields: %{"Name" => "A"}})]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "app1", table_id: "tbl1"},
                 %{credentials: credentials}
               )

      refute Map.has_key?(result, :offset)
    end

    test "response handles record list with offset from fixture" do
      payload = fixture!("record_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      assert result.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
      assert length(result.records) == 2
    end

    test "response handles record list without offset" do
      payload = %{
        "records" => [
          %{"id" => "rec1", "fields" => %{"Name" => "A"}}
        ]
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      refute Map.has_key?(result, :offset)
    end

    test "response handles empty records list" do
      payload = %{"records" => []}
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      assert result.records == []
      refute Map.has_key?(result, :offset)
    end

    test "response handles pagination fixture" do
      payload = fixture!("pagination_common.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      assert result.records == []
      assert result.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
    end
  end

  describe "normalized output" do
    test "list_records returns normalized Record structs as maps" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "Task 2"}})
      ]

      MockClient.stub(list_records: {:ok, %{records: records}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListRecords.run(
                 %{base_id: "app1", table_id: "tbl1"},
                 %{credentials: credentials}
               )

      for record <- result.records do
        assert is_map(record)
        assert Map.has_key?(record, :record_id)
        assert Map.has_key?(record, :fields)
        refute is_struct(record)
      end
    end

    test "list_bases returns normalized Base structs as maps" do
      bases = [Base.new!(%{base_id: "app1", name: "Test Base"})]
      MockClient.stub(list_bases: {:ok, bases})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} = ListBases.run(%{}, %{credentials: credentials})

      for base <- result.bases do
        assert is_map(base)
        assert Map.has_key?(base, :base_id)
        refute is_struct(base)
      end
    end

    test "list_tables returns normalized Table structs as maps" do
      tables = [Table.new!(%{table_id: "tbl1", name: "Tasks"})]

      MockClient.stub(list_tables: {:ok, %{tables: tables}})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, result} =
               ListTables.run(%{base_id: "app1"}, %{credentials: credentials})

      for table <- result.tables do
        assert is_map(table)
        assert Map.has_key?(table, :table_id)
        refute is_struct(table)
      end
    end

    test "get_record returns normalized Record struct as map" do
      record = Record.new!(%{record_id: "rec1", fields: %{"Name" => "Test"}})
      MockClient.stub(get_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "token"}

      assert {:ok, %{record: result}} =
               Jido.Connect.Airtable.Handlers.Actions.GetRecord.run(
                 %{base_id: "app1", table_id: "tbl1", record_id: "rec1"},
                 %{credentials: credentials}
               )

      assert is_map(result)
      assert result.record_id == "rec1"
      refute is_struct(result)
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "airtable", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
