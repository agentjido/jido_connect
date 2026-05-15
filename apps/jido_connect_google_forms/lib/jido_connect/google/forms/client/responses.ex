defmodule Jido.Connect.Google.Forms.Client.Responses do
  @moduledoc "Google Forms responses API boundary."

  alias Jido.Connect.Google.Forms.Client.{Response, Transport}

  def list_responses(%{form_id: form_id} = params, access_token)
      when is_binary(form_id) and is_binary(access_token) do
    query_params = list_responses_query(params)

    access_token
    |> Transport.forms_request()
    |> Req.get(
      url: "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}/responses",
      params: query_params
    )
    |> Response.handle_response_list_response()
  end

  def get_response(%{form_id: form_id, response_id: response_id} = params, access_token)
      when is_binary(form_id) and is_binary(response_id) and is_binary(access_token) do
    query_params = get_response_query(params)

    access_token
    |> Transport.forms_request()
    |> Req.get(
      url:
        "/v1/forms/#{URI.encode(form_id, &URI.char_unreserved?/1)}/responses/#{URI.encode(response_id, &URI.char_unreserved?/1)}",
      params: query_params
    )
    |> Response.handle_response_get_response()
  end

  defp list_responses_query(params) do
    []
    |> maybe_put(:pageSize, Map.get(params, :page_size))
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:filter, Map.get(params, :filter))
  end

  defp get_response_query(_params) do
    []
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
