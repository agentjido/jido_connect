defmodule Jido.Connect.Airtable.Handlers.Actions.CreateRecordsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.CreateRecords
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "creates multiple records with typed field payloads" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "Task 1", "Priority" => "High"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "Task 2", "Priority" => "Low"}})
      ]

      MockClient.stub(create_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [
                     %{"Name" => "Task 1", "Priority" => "High"},
                     %{"Name" => "Task 2", "Priority" => "Low"}
                   ]
                 },
                 %{credentials: credentials}
               )

      assert length(result) == 2
      assert Enum.at(result, 0).record_id == "rec1"
      assert Enum.at(result, 1).record_id == "rec2"
      assert Enum.at(result, 0).fields["Priority"] == "High"
    end

    test "creates records with typecast enabled" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Count" => 42}})
      ]

      MockClient.stub(create_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [%{"Count" => "42"}],
                   typecast: true
                 },
                 %{credentials: credentials}
               )

      assert length(result) == 1
    end

    test "returns error for empty records list" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_records}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: []
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when batch size exceeds maximum" do
      fields_list = for i <- 1..11, do: %{"Name" => "Task #{i}"}

      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :batch_size_exceeded}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: fields_list
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when records is not a list" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_records}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: "not a list"
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Table not found"}}

      MockClient.stub(create_records: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblInvalid",
                   records: [%{"Name" => "Test"}]
                 },
                 %{credentials: credentials}
               )
    end
  end
end
