defmodule Jido.Connect.Google.Meet.Client.Spaces do
  @moduledoc "Google Meet spaces API boundary."

  alias Jido.Connect.Google.Meet.Client.{Params, Response, Transport}

  def create_space(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v2/spaces",
      json: Params.space_body(params),
      params: Params.fields_params(params)
    )
    |> Response.handle_space_response()
  end

  def get_space(%{space_name: space_name} = params, access_token)
      when is_binary(space_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(space_name)}",
      params: Params.fields_params(params)
    )
    |> Response.handle_space_response()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
