defmodule Jido.Connect.Airtable.Handlers.Actions.DeleteRecordsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.DeleteRecords
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "deletes multiple records" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{}}),
        Record.new!(%{record_id: "rec2", fields: %{}})
      ]

      MockClient.stub(delete_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: ["rec1", "rec2"]
                 },
                 %{credentials: credentials}
               )

      assert length(result) == 2
      assert Enum.at(result, 0).record_id == "rec1"
      assert Enum.at(result, 1).record_id == "rec2"
    end

    test "deletes records returning fields from before deletion" do
      records = [
        Record.new!(%{record_id: "rec1", fields: %{"Name" => "Deleted"}})
      ]

      MockClient.stub(delete_records: {:ok, records})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{records: result}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: ["rec1"]
                 },
                 %{credentials: credentials}
               )

      assert Enum.at(result, 0).fields["Name"] == "Deleted"
    end

    test "returns error for empty record_ids list" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_records}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: []
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when batch size exceeds maximum" do
      record_ids = for i <- 1..11, do: "rec#{i}"

      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :batch_size_exceeded}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: record_ids
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when record_ids is not a list" do
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_batch_records}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: "not a list"
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(delete_records: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               DeleteRecords.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_ids: ["recInvalid"]
                 },
                 %{credentials: credentials}
               )
    end
  end
end
