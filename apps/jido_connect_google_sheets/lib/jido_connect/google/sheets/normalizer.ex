defmodule Jido.Connect.Google.Sheets.Normalizer do
  @moduledoc "Normalizes Google Sheets API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Sheets.{
    DeveloperMetadata,
    Sheet,
    Spreadsheet,
    UpdateResult,
    ValueRange
  }

  @doc "Normalizes a Google spreadsheet payload."
  @spec spreadsheet(map()) :: {:ok, Spreadsheet.t()} | {:error, term()}
  def spreadsheet(payload) when is_map(payload) do
    properties = Data.get(payload, "properties", %{}) || %{}

    %{
      spreadsheet_id: Data.get(payload, "spreadsheetId"),
      title: Data.get(properties, "title"),
      locale: Data.get(properties, "locale"),
      time_zone: Data.get(properties, "timeZone"),
      spreadsheet_url: Data.get(payload, "spreadsheetUrl"),
      sheets: payload |> Data.get("sheets", []) |> Enum.map(&sheet!/1)
    }
    |> Data.compact()
    |> Spreadsheet.new()
  end

  @doc "Normalizes a Google sheet/tab payload."
  @spec sheet(map()) :: {:ok, Sheet.t()} | {:error, term()}
  def sheet(payload) when is_map(payload) do
    properties = Data.get(payload, "properties", %{}) || %{}
    grid = Data.get(properties, "gridProperties", %{}) || %{}

    %{
      sheet_id: Data.get(properties, "sheetId"),
      title: Data.get(properties, "title"),
      index: Data.get(properties, "index"),
      type: Data.get(properties, "sheetType"),
      row_count: Data.get(grid, "rowCount"),
      column_count: Data.get(grid, "columnCount"),
      hidden?: Data.get(properties, "hidden", false)
    }
    |> Data.compact()
    |> Sheet.new()
  end

  @doc "Normalizes a Google value range payload."
  @spec value_range(map()) :: {:ok, ValueRange.t()} | {:error, term()}
  def value_range(payload) when is_map(payload) do
    %{
      range: Data.get(payload, "range"),
      major_dimension: Data.get(payload, "majorDimension", "ROWS"),
      values: Data.get(payload, "values", [])
    }
    |> Data.compact()
    |> ValueRange.new()
  end

  @doc "Normalizes a Google update response payload."
  @spec update_result(map()) :: {:ok, UpdateResult.t()} | {:error, term()}
  def update_result(payload) when is_map(payload) do
    updates = Data.get(payload, "updates", %{}) || %{}

    %{
      spreadsheet_id: Data.get(payload, "spreadsheetId"),
      updated_range: Data.get(payload, "updatedRange", Data.get(updates, "updatedRange")),
      updated_rows: Data.get(payload, "updatedRows", Data.get(updates, "updatedRows", 0)),
      updated_columns:
        Data.get(payload, "updatedColumns", Data.get(updates, "updatedColumns", 0)),
      updated_cells: Data.get(payload, "updatedCells", Data.get(updates, "updatedCells", 0)),
      table_range: Data.get(payload, "tableRange"),
      cleared_range: Data.get(payload, "clearedRange")
    }
    |> Data.compact()
    |> UpdateResult.new()
  end

  @doc "Normalizes a Google developer metadata payload."
  @spec developer_metadata(map()) :: {:ok, DeveloperMetadata.t()} | {:error, term()}
  def developer_metadata(payload) when is_map(payload) do
    %{
      metadata_id: Data.get(payload, "metadataId"),
      metadata_key: Data.get(payload, "metadataKey"),
      metadata_value: Data.get(payload, "metadataValue"),
      location: Data.get(payload, "location", %{}),
      visibility: Data.get(payload, "visibility")
    }
    |> Data.compact()
    |> DeveloperMetadata.new()
  end

  defp sheet!(payload) do
    case sheet(payload) do
      {:ok, sheet} -> sheet
      {:error, error} -> raise error
    end
  end
end
