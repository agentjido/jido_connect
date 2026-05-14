defmodule Jido.Connect.Google.Sheets.Client.Response do
  @moduledoc "Google Sheets response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Sheets.{Client.Transport, Normalizer}

  def handle_spreadsheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.spreadsheet(body)
  end

  def handle_spreadsheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets spreadsheet response was invalid", body)
  end

  def handle_spreadsheet_response(response), do: Transport.handle_error_response(response)

  def handle_value_range_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.value_range(body)
  end

  def handle_value_range_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets values response was invalid", body)
  end

  def handle_value_range_response(response), do: Transport.handle_error_response(response)

  def handle_value_ranges_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, value_ranges} <- normalize_value_ranges(Data.get(body, "valueRanges", [])) do
      {:ok,
       %{
         spreadsheet_id: Data.get(body, "spreadsheetId"),
         value_ranges: value_ranges
       }
       |> Data.compact()}
    end
  end

  def handle_value_ranges_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Sheets batch get values response was invalid",
      body
    )
  end

  def handle_value_ranges_response(response), do: Transport.handle_error_response(response)

  def handle_update_result_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.update_result(body)
  end

  def handle_update_result_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets update response was invalid", body)
  end

  def handle_update_result_response(response), do: Transport.handle_error_response(response)

  def handle_batch_update_values_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, responses} <- normalize_update_responses(Data.get(body, "responses", [])) do
      {:ok,
       %{
         spreadsheet_id: Data.get(body, "spreadsheetId"),
         total_updated_rows: Data.get(body, "totalUpdatedRows", 0),
         total_updated_columns: Data.get(body, "totalUpdatedColumns", 0),
         total_updated_cells: Data.get(body, "totalUpdatedCells", 0),
         total_updated_sheets: Data.get(body, "totalUpdatedSheets", 0),
         responses: responses
       }
       |> Data.compact()}
    end
  end

  def handle_batch_update_values_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Sheets batch update values response was invalid",
      body
    )
  end

  def handle_batch_update_values_response(response), do: Transport.handle_error_response(response)

  def handle_batch_clear_values_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok,
     %{
       spreadsheet_id: Data.get(body, "spreadsheetId"),
       cleared_ranges: Data.get(body, "clearedRanges", [])
     }
     |> Data.compact()}
  end

  def handle_batch_clear_values_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Sheets batch clear values response was invalid",
      body
    )
  end

  def handle_batch_clear_values_response(response), do: Transport.handle_error_response(response)

  def handle_add_sheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, properties} <- reply_properties(body, "addSheet") do
      Normalizer.sheet(%{"properties" => properties})
    end
  end

  def handle_add_sheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets add sheet response was invalid", body)
  end

  def handle_add_sheet_response(response), do: Transport.handle_error_response(response)

  def handle_rename_sheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, properties} <- reply_properties(body, "updateSheetProperties") do
      Normalizer.sheet(%{"properties" => properties})
    end
  end

  def handle_rename_sheet_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets rename sheet response was invalid", body)
  end

  def handle_rename_sheet_response(response), do: Transport.handle_error_response(response)

  def handle_delete_sheet_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{spreadsheet_id: Map.get(params, :spreadsheet_id), sheet_id: Map.get(params, :sheet_id)}}
  end

  def handle_delete_sheet_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok,
     %{
       spreadsheet_id: Data.get(body, "spreadsheetId"),
       replies: Data.get(body, "replies", []),
       updated_spreadsheet: Data.get(body, "updatedSpreadsheet")
     }
     |> Enum.reject(fn {_key, value} -> is_nil(value) end)
     |> Map.new()}
  end

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Sheets batch update response was invalid", body)
  end

  def handle_batch_update_response(response), do: Transport.handle_error_response(response)

  defp reply_properties(body, key) do
    body
    |> Data.get("replies", [])
    |> Enum.find_value(fn reply ->
      reply
      |> Data.get(key)
      |> case do
        %{} = wrapper -> Data.get(wrapper, "properties")
        _other -> nil
      end
    end)
    |> case do
      %{} = properties ->
        {:ok, properties}

      _missing ->
        Transport.invalid_success_response(
          "Google Sheets batch update response was invalid",
          body
        )
    end
  end

  defp normalize_value_ranges(value_ranges) when is_list(value_ranges) do
    normalize_many(value_ranges, &Normalizer.value_range/1)
  end

  defp normalize_value_ranges(value_ranges) do
    Transport.invalid_success_response(
      "Google Sheets batch get values response was invalid",
      value_ranges
    )
  end

  defp normalize_update_responses(responses) when is_list(responses) do
    normalize_many(responses, &Normalizer.update_result/1)
  end

  defp normalize_update_responses(responses) do
    Transport.invalid_success_response(
      "Google Sheets batch update values response was invalid",
      responses
    )
  end

  defp normalize_many(values, normalizer) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case normalizer.(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end
end
