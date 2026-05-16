defmodule Jido.Connect.Airtable.Handlers.Actions.CreateRecordTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Handlers.Actions.CreateRecord
  alias Jido.Connect.Airtable.Record

  describe "run/2" do
    test "creates record with typed field payload" do
      record =
        Record.new!(%{
          record_id: "rec2",
          fields: %{"Name" => "New Task", "Priority" => "High", "Count" => 5}
        })

      MockClient.stub(create_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               CreateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   fields: %{"Name" => "New Task", "Priority" => "High", "Count" => 5}
                 },
                 %{credentials: credentials}
               )

      assert result.record_id == "rec2"
      assert result.fields["Name"] == "New Task"
      assert result.fields["Priority"] == "High"
      assert result.fields["Count"] == 5
    end

    test "creates record with typecast enabled" do
      record =
        Record.new!(%{
          record_id: "rec3",
          fields: %{"Name" => "Auto-typed", "Number" => "42"}
        })

      MockClient.stub(create_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               CreateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   fields: %{"Name" => "Auto-typed", "Number" => "42"},
                   typecast: true
                 },
                 %{credentials: credentials}
               )

      assert result.record_id == "rec3"
    end

    test "creates record with empty fields map" do
      record = Record.new!(%{record_id: "rec4", fields: %{}})

      MockClient.stub(create_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               CreateRecord.run(
                 %{base_id: "appTest1", table_id: "tblTest1", fields: %{}},
                 %{credentials: credentials}
               )

      assert result.record_id == "rec4"
      assert result.fields == %{}
    end

    test "creates record with complex nested fields" do
      record =
        Record.new!(%{
          record_id: "rec5",
          fields: %{
            "Name" => "Complex",
            "Tags" => ["urgent", "backend"],
            "Metadata" => %{"source" => "api"}
          }
        })

      MockClient.stub(create_record: {:ok, record})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, %{record: result}} =
               CreateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   fields: %{
                     "Name" => "Complex",
                     "Tags" => ["urgent", "backend"],
                     "Metadata" => %{"source" => "api"}
                   }
                 },
                 %{credentials: credentials}
               )

      assert result.fields["Tags"] == ["urgent", "backend"]
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{
           provider: :airtable,
           message: "INVALID_REQUEST_UNKNOWN",
           details: %{message: "Could not find field in table"}
         }}

      MockClient.stub(create_record: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateRecord.run(
                 %{
                   base_id: "appTest1",
                   table_id: "tblTest1",
                   fields: %{"InvalidField" => "value"}
                 },
                 %{credentials: credentials}
               )
    end
  end
end
