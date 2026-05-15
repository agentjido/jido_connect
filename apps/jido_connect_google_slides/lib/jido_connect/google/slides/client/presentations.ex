defmodule Jido.Connect.Google.Slides.Client.Presentations do
  @moduledoc "Google Slides presentation API boundary."

  alias Jido.Connect.Google.Slides.Client.{Response, Transport}

  def get_presentation(%{presentation_id: presentation_id} = params, access_token)
      when is_binary(presentation_id) and is_binary(access_token) do
    query_params = get_presentation_query(params)

    access_token
    |> Transport.slides_request()
    |> Req.get(
      url: "/v1/presentations/#{URI.encode(presentation_id, &URI.char_unreserved?/1)}",
      params: query_params
    )
    |> Response.handle_presentation_response()
  end

  def create_presentation(%{title: title}, access_token)
      when is_binary(title) and is_binary(access_token) do
    body = %{title: title}

    access_token
    |> Transport.slides_request()
    |> Req.post(url: "/v1/presentations", json: body)
    |> Response.handle_presentation_response()
  end

  def batch_update(
        %{presentation_id: presentation_id, requests: requests} = params,
        access_token
      )
      when is_binary(presentation_id) and is_list(requests) and is_binary(access_token) do
    body = %{requests: requests}

    body =
      case Map.get(params, :write_control) do
        nil -> body
        write_control -> Map.put(body, :writeControl, write_control)
      end

    access_token
    |> Transport.slides_request()
    |> Req.post(
      url:
        "/v1/presentations/#{URI.encode(presentation_id, &URI.char_unreserved?/1)}:batchUpdate",
      json: body
    )
    |> Response.handle_batch_update_response()
  end

  def get_page_thumbnail(
        %{presentation_id: presentation_id, page_object_id: page_object_id} = params,
        access_token
      )
      when is_binary(presentation_id) and is_binary(page_object_id) and is_binary(access_token) do
    query_params = thumbnail_query(params)

    access_token
    |> Transport.slides_request()
    |> Req.get(
      url:
        "/v1/presentations/#{URI.encode(presentation_id, &URI.char_unreserved?/1)}/pages/#{URI.encode(page_object_id, &URI.char_unreserved?/1)}/thumbnail",
      params: query_params
    )
    |> Response.handle_thumbnail_response()
  end

  defp thumbnail_query(params) do
    case Map.get(params, :thumbnail_properties) do
      nil -> []
      props -> [thumbnailProperties: props]
    end
  end

  defp get_presentation_query(params) do
    case Map.get(params, :fields) do
      nil -> []
      fields -> [fields: fields]
    end
  end
end
