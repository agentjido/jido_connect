defmodule Jido.Connect.Google.Sheets.Client.DeveloperMetadata do
  @moduledoc "Google Sheets developer metadata API boundary."

  alias Jido.Connect.Google.Sheets.{DataFilter, Client.Response, Client.Transport}

  def get_developer_metadata(
        %{spreadsheet_id: spreadsheet_id, metadata_id: metadata_id},
        access_token
      )
      when is_binary(spreadsheet_id) and is_integer(metadata_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: developer_metadata_url(spreadsheet_id, metadata_id))
    |> Response.handle_developer_metadata_response()
  end

  def search_developer_metadata(
        %{spreadsheet_id: spreadsheet_id, data_filters: data_filters},
        access_token
      )
      when is_binary(spreadsheet_id) and is_list(data_filters) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v4/spreadsheets/#{encode_path_segment(spreadsheet_id)}/developerMetadata:search",
      json: %{dataFilters: DataFilter.to_google_filters(data_filters)}
    )
    |> Response.handle_developer_metadata_search_response()
  end

  defp developer_metadata_url(spreadsheet_id, metadata_id) do
    "/v4/spreadsheets/#{encode_path_segment(spreadsheet_id)}/developerMetadata/#{metadata_id}"
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
