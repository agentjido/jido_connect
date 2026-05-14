defmodule Jido.Connect.Google.Analytics.Client.Metadata do
  @moduledoc "Google Analytics metadata API boundary."

  alias Jido.Connect.Google.Analytics.Client.{Response, Transport}

  def get_metadata(%{property: property} = params, access_token)
      when is_binary(property) and is_binary(access_token) do
    access_token
    |> Transport.data_request()
    |> Req.get(
      url: "/v1beta/#{encode_resource_name(property)}/metadata",
      params: fields_params(params)
    )
    |> Response.handle_metadata_response()
  end

  defp fields_params(params) do
    params
    |> Map.take([:fields])
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
