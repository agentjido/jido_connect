defmodule Jido.Connect.Google.Forms.Client.Forms do
  @moduledoc "Google Forms form API boundary."

  alias Jido.Connect.Google.Forms.Client.{Response, Transport}

  def get_form(%{form_id: form_id} = params, access_token)
      when is_binary(form_id) and is_binary(access_token) do
    query_params = get_form_query(params)

    access_token
    |> Transport.forms_request()
    |> Req.get(
      url: "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}",
      params: query_params
    )
    |> Response.handle_form_response()
  end

  def create_form(%{title: title} = params, access_token)
      when is_binary(title) and is_binary(access_token) do
    body = create_form_body(params)

    access_token
    |> Transport.forms_request()
    |> Req.post(url: "/v1/forms", json: body)
    |> Response.handle_form_response()
  end

  def batch_update(%{form_id: form_id, requests: requests} = params, access_token)
      when is_binary(form_id) and is_list(requests) and is_binary(access_token) do
    body = batch_update_body(params)

    access_token
    |> Transport.forms_request()
    |> Req.post(
      url: "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}:batchUpdate",
      json: body
    )
    |> Response.handle_batch_update_response()
  end

  defp get_form_query(params) do
    []
    |> maybe_put(:includeLinkedSheets, Map.get(params, :include_linked_sheets))
  end

  defp create_form_body(params) do
    info = %{title: Map.fetch!(params, :title)}

    info =
      case Map.get(params, :description) do
        nil -> info
        description -> Map.put(info, :description, description)
      end

    %{info: info}
  end

  defp batch_update_body(params) do
    body = %{requests: Map.get(params, :requests)}

    case Map.get(params, :write_control) do
      nil -> body
      write_control -> Map.put(body, :writeControl, write_control)
    end
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
