defmodule Jido.Connect.Airtable.Handlers.Actions.GetRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.GetRecord
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "returns record on success" do
      record = Record.new!(%{record_id: "rec1", fields: %{"Name" => "Test Task"}})
      MockClient.stub(get_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               GetRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
                 %{credentials: credentials}
               )

      assert result.record_id == "rec1"
      assert result.fields["Name"] == "Test Task"
    end

    test "returns record with complex fields" do
      record =
        Record.new!(%{
          record_id: "rec1",
          fields: %{
            "Name" => "Complex Task",
            "Status" => "In progress",
            "Priority" => "High",
            "Tags" => ["urgent", "backend"]
          }
        })

      MockClient.stub(get_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               GetRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
                 %{credentials: credentials}
               )

      assert result.fields["Name"] == "Complex Task"
      assert result.fields["Tags"] == ["urgent", "backend"]
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Not found"}}

      MockClient.stub(get_record: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", record_id: "recInvalid"},
                 %{credentials: credentials}
               )
    end
  end
end
