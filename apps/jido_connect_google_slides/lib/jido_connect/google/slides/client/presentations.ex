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

  defp get_presentation_query(params) do
    case Map.get(params, :fields) do
      nil -> []
      fields -> [fields: fields]
    end
  end
end
