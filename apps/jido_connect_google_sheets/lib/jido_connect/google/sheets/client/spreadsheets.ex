defmodule Jido.Connect.Google.Sheets.Client.Spreadsheets do
  @moduledoc "Google Sheets spreadsheet API boundary."

  alias Jido.Connect.Google.Sheets.Client.{Params, Response, Transport}

  def get_spreadsheet(%{spreadsheet_id: spreadsheet_id} = params, access_token)
      when is_binary(spreadsheet_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v4/spreadsheets/#{URI.encode(spreadsheet_id)}",
      params: Params.spreadsheet_get_params(params)
    )
    |> Response.handle_spreadsheet_response()
  end

  def create_spreadsheet(%{title: title} = params, access_token)
      when is_binary(title) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v4/spreadsheets", json: create_spreadsheet_body(params))
    |> Response.handle_spreadsheet_response()
  end

  def add_sheet(%{spreadsheet_id: spreadsheet_id, title: title} = params, access_token)
      when is_binary(spreadsheet_id) and is_binary(title) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: batch_update_url(spreadsheet_id),
      json: %{requests: [add_sheet_request(params)]}
    )
    |> Response.handle_add_sheet_response()
  end

  def delete_sheet(%{spreadsheet_id: spreadsheet_id, sheet_id: sheet_id} = params, access_token)
      when is_binary(spreadsheet_id) and is_integer(sheet_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: batch_update_url(spreadsheet_id),
      json: %{requests: [%{deleteSheet: %{sheetId: sheet_id}}]}
    )
    |> Response.handle_delete_sheet_response(params)
  end

  def rename_sheet(
        %{spreadsheet_id: spreadsheet_id, sheet_id: sheet_id, title: title},
        access_token
      )
      when is_binary(spreadsheet_id) and is_integer(sheet_id) and is_binary(title) and
             is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: batch_update_url(spreadsheet_id),
      json: %{
        requests: [
          %{
            updateSheetProperties: %{
              properties: %{sheetId: sheet_id, title: title},
              fields: "title"
            }
          }
        ]
      }
    )
    |> Response.handle_rename_sheet_response()
  end

  def batch_update(%{spreadsheet_id: spreadsheet_id, requests: requests} = params, access_token)
      when is_binary(spreadsheet_id) and is_list(requests) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: batch_update_url(spreadsheet_id), json: batch_update_body(params))
    |> Response.handle_batch_update_response()
  end

  defp add_sheet_request(params) do
    properties =
      %{
        title: Map.get(params, :title),
        index: Map.get(params, :index),
        gridProperties: grid_properties(params)
      }
      |> compact()

    %{addSheet: %{properties: properties}}
  end

  defp create_spreadsheet_body(params) do
    %{
      properties:
        %{
          title: Map.get(params, :title),
          locale: Map.get(params, :locale),
          timeZone: Map.get(params, :time_zone)
        }
        |> compact(),
      sheets: create_sheets(params)
    }
    |> compact()
  end

  defp create_sheets(params) do
    params
    |> sheet_properties()
    |> case do
      nil -> nil
      properties -> [%{properties: properties}]
    end
  end

  defp sheet_properties(params) do
    %{
      title: Map.get(params, :sheet_title),
      gridProperties: grid_properties(params)
    }
    |> compact()
    |> case do
      empty when empty == %{} -> nil
      properties -> properties
    end
  end

  defp grid_properties(params) do
    %{
      rowCount: Map.get(params, :row_count),
      columnCount: Map.get(params, :column_count)
    }
    |> compact()
    |> case do
      empty when empty == %{} -> nil
      grid -> grid
    end
  end

  defp batch_update_url(spreadsheet_id) do
    "/v4/spreadsheets/#{URI.encode(spreadsheet_id, &URI.char_unreserved?/1)}:batchUpdate"
  end

  defp batch_update_body(params) do
    %{
      requests: Map.get(params, :requests),
      includeSpreadsheetInResponse: Map.get(params, :include_spreadsheet_in_response),
      responseRanges: Map.get(params, :response_ranges),
      responseIncludeGridData: Map.get(params, :response_include_grid_data)
    }
    |> compact()
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
