defmodule Jido.Connect.Google.Docs.Client.Documents do
  @moduledoc "Google Docs document API boundary."

  alias Jido.Connect.Google.Docs.BatchUpdateRequest
  alias Jido.Connect.Google.Docs.Client.{Response, Transport}

  def get_document(%{document_id: document_id} = params, access_token)
      when is_binary(document_id) and is_binary(access_token) do
    query_params = get_document_query(params)

    access_token
    |> Transport.docs_request()
    |> Req.get(
      url: "/v1/documents/#{URI.encode(document_id, &URI.char_unreserved?/1)}",
      params: query_params
    )
    |> Response.handle_document_response()
  end

  def create_document(%{title: title}, access_token)
      when is_binary(title) and is_binary(access_token) do
    body = %{title: title}

    access_token
    |> Transport.docs_request()
    |> Req.post(url: "/v1/documents", json: body)
    |> Response.handle_document_response()
  end

  def batch_update(%{document_id: document_id, requests: requests} = params, access_token)
      when is_binary(document_id) and is_list(requests) and is_binary(access_token) do
    body = batch_update_body(params)

    access_token
    |> Transport.docs_request()
    |> Req.post(
      url: "/v1/documents/#{URI.encode(document_id, &URI.char_unreserved?/1)}:batchUpdate",
      json: body
    )
    |> Response.handle_batch_update_response()
  end

  defp get_document_query(params) do
    []
    |> maybe_put(:suggestionsViewMode, Map.get(params, :suggestions_view_mode))
    |> maybe_put(:includeTabsContent, Map.get(params, :include_tabs_content))
  end

  defp batch_update_body(params) do
    body = %{requests: Enum.map(params.requests, &encode_operation/1)}

    case Map.get(params, :write_control) do
      nil -> body
      write_control -> Map.put(body, :writeControl, write_control)
    end
  end

  defp encode_operation(request) when is_map(request) and map_size(request) == 1 do
    [{key, payload}] = Map.to_list(request)
    %{BatchUpdateRequest.rest_operation_name(key) => payload}
  end

  defp encode_operation(request), do: request

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
