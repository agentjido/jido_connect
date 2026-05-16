defmodule Jido.Connect.Airtable.Handlers.Actions.UpdateRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.UpdateRecord
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "updates record with typed field payload" do
      record =
        Record.new!(%{
          record_id: "rec1",
          fields: %{"Name" => "Updated Task", "Status" => "Done"}
        })

      MockClient.stub(update_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               UpdateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_id: "rec1",
                   fields: %{"Name" => "Updated Task", "Status" => "Done"}
                 },
                 %{credentials: credentials}
               )

      assert result.record_id == "rec1"
      assert result.fields["Name"] == "Updated Task"
      assert result.fields["Status"] == "Done"
    end

    test "updates record with partial fields" do
      record =
        Record.new!(%{
          record_id: "rec1",
          fields: %{"Name" => "Only Name Updated"}
        })

      MockClient.stub(update_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               UpdateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_id: "rec1",
                   fields: %{"Name" => "Only Name Updated"}
                 },
                 %{credentials: credentials}
               )

      assert result.fields["Name"] == "Only Name Updated"
    end

    test "updates record with typecast enabled" do
      record =
        Record.new!(%{
          record_id: "rec1",
          fields: %{"Count" => 10}
        })

      MockClient.stub(update_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               UpdateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_id: "rec1",
                   fields: %{"Count" => "10"},
                   typecast: true
                 },
                 %{credentials: credentials}
               )

      assert result.fields["Count"] == 10
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(update_record: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   record_id: "recInvalid",
                   fields: %{"Name" => "Updated"}
                 },
                 %{credentials: credentials}
               )
    end
  end
end
