defmodule Jido.Connect.Airtable.Handlers.Actions.DeleteRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.DeleteRecord
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "deletes record and returns deleted record" do
      record = Record.new!(%{record_id: "rec1", fields: %{}})

      MockClient.stub(delete_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               DeleteRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
                 %{credentials: credentials}
               )

      assert result.record_id == "rec1"
    end

    test "deletes record returning fields from before deletion" do
      record = Record.new!(%{record_id: "rec1", fields: %{"Name" => "Deleted"}})

      MockClient.stub(delete_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               DeleteRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
                 %{credentials: credentials}
               )

      assert result.fields["Name"] == "Deleted"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(delete_record: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               DeleteRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "recInvalid"},
                 %{credentials: credentials}
               )
    end
  end
end
