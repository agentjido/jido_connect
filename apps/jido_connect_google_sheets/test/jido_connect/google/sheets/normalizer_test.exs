defmodule Jido.Connect.Google.Sheets.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Sheets.{
    DeveloperMetadata,
    Normalizer,
    Range,
    Sheet,
    Spreadsheet,
    UpdateResult,
    ValueRange
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes spreadsheet payloads" do
    payload = %{
      "spreadsheetId" => "sheet123",
      "spreadsheetUrl" => "https://docs.google.com/spreadsheets/d/sheet123",
      "properties" => %{
        "title" => "Budget",
        "locale" => "en_US",
        "timeZone" => "America/Chicago"
      },
      "sheets" => [
        %{
          "properties" => %{
            "sheetId" => 0,
            "title" => "Sheet1",
            "index" => 0,
            "sheetType" => "GRID",
            "gridProperties" => %{"rowCount" => 1000, "columnCount" => 26}
          }
        }
      ]
    }

    assert {:ok, %Spreadsheet{} = spreadsheet} = Normalizer.spreadsheet(payload)
    assert spreadsheet.spreadsheet_id == "sheet123"
    assert spreadsheet.title == "Budget"
    assert [%{sheet_id: 0, title: "Sheet1", row_count: 1000}] = spreadsheet.sheets
  end

  test "normalizes value ranges" do
    assert {:ok, %ValueRange{} = range} =
             Normalizer.value_range(%{
               "range" => "Sheet1!A1:B2",
               "majorDimension" => "ROWS",
               "values" => [["Name", "Count"], ["A", 1]]
             })

    assert range.range == "Sheet1!A1:B2"
    assert range.values == [["Name", "Count"], ["A", 1]]
  end

  test "normalizes update results" do
    assert {:ok, %UpdateResult{} = result} =
             Normalizer.update_result(%{
               "spreadsheetId" => "sheet123",
               "updatedRange" => "Sheet1!A1:B2",
               "updatedRows" => 2,
               "updatedColumns" => 2,
               "updatedCells" => 4
             })

    assert result.spreadsheet_id == "sheet123"
    assert result.updated_range == "Sheet1!A1:B2"
    assert result.updated_cells == 4
  end

  test "normalizes append update results" do
    assert {:ok, %UpdateResult{} = result} =
             Normalizer.update_result(%{
               "spreadsheetId" => "sheet123",
               "tableRange" => "Sheet1!A1:B2",
               "updates" => %{
                 "updatedRange" => "Sheet1!A3:B3",
                 "updatedRows" => 1,
                 "updatedColumns" => 2,
                 "updatedCells" => 2
               }
             })

    assert result.table_range == "Sheet1!A1:B2"
    assert result.updated_range == "Sheet1!A3:B3"
    assert result.updated_cells == 2
  end

  test "normalizes clear results" do
    assert {:ok, %UpdateResult{} = result} =
             Normalizer.update_result(%{
               "spreadsheetId" => "sheet123",
               "clearedRange" => "Sheet1!A1:B2"
             })

    assert result.cleared_range == "Sheet1!A1:B2"
    assert result.updated_cells == 0
  end

  test "normalizes developer metadata" do
    assert {:ok, %DeveloperMetadata{} = metadata} =
             Normalizer.developer_metadata(%{
               "metadataId" => 123,
               "metadataKey" => "sync_id",
               "metadataValue" => "abc",
               "visibility" => "DOCUMENT",
               "location" => %{"locationType" => "SPREADSHEET"}
             })

    assert metadata.metadata_id == 123
    assert metadata.metadata_key == "sync_id"
    assert metadata.location == %{"locationType" => "SPREADSHEET"}
  end

  test "struct constructors expose schema defaults" do
    ConnectorContracts.assert_struct_defaults(Sheet, %{sheet_id: 0, title: "Sheet1"},
      hidden?: false,
      metadata: %{}
    )

    assert {:error, _error} = Sheet.new(%{title: "Missing id"})

    ConnectorContracts.assert_struct_defaults(Spreadsheet, %{spreadsheet_id: "sheet123"},
      sheets: [],
      metadata: %{}
    )

    assert {:error, _error} = Spreadsheet.new(%{})

    ConnectorContracts.assert_struct_defaults(ValueRange, %{range: "Sheet1!A1:B2"},
      major_dimension: "ROWS",
      values: [],
      metadata: %{}
    )

    assert {:error, _error} = ValueRange.new(%{})

    ConnectorContracts.assert_struct_defaults(UpdateResult, %{},
      updated_rows: 0,
      updated_columns: 0,
      updated_cells: 0,
      metadata: %{}
    )

    ConnectorContracts.assert_struct_defaults(
      DeveloperMetadata,
      %{metadata_id: 123, metadata_key: "sync_id", visibility: "DOCUMENT"},
      location: %{},
      metadata: %{}
    )

    ConnectorContracts.assert_struct_defaults(Range, %{a1: "Sheet1!A1:B2"}, metadata: %{})
    assert {:error, _error} = Range.new(%{})
  end
end
