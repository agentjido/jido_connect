defmodule Jido.Connect.Airtable.Handlers.Actions.UpdateRecordsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.UpdateRecords
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "updates multiple records with typed field payloads" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "Updated 1"}}),
        Record.new!(%{record_id: "rec2", fields: %{"Name" => "Updated 2"}})
      ]

      MockClient.stub(update_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [
                     %{id: "rec1", fields: %{"Name" => "Updated 1"}},
                     %{id: "rec2", fields: %{"Name" => "Updated 2"}}
                   ]
                 },
                 %{credentials: credentials}
               )

      assert length(result) == 2
      assert Enum.at(result, 0).record_id == "rec1"
      assert Enum.at(result, 1).record_id == "rec2"
    end

    test "updates records with typecast enabled" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Count" => 42}})
      ]

      MockClient.stub(update_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [%{id: "rec1", fields: %{"Count" => "42"}}],
                   typecast: true
                 },
                 %{credentials: credentials}
               )

      assert length(result) == 1
    end

    test "returns error for empty records list" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_records}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: []
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when batch size exceeds maximum" do
      records = for i <- 1..11, do: %{id: "rec#{i}", fields: %{"Name" => "Updated"}}

      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :batch_size_exceeded}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: records
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when record is missing :id key" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_record_shape}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [%{fields: %{"Name" => "No ID"}}]
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when record is missing :fields key" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_record_shape}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [%{id: "rec1"}]
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when record is not a map" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_record_shape}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: ["not a map"]
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(update_records: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   records: [%{id: "recInvalid", fields: %{"Name" => "Updated"}}]
                 },
                 %{credentials: credentials}
               )
    end
  end
end
