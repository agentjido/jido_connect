defmodule Jido.Connect.Google.SearchConsole.Client.Sites do
  @moduledoc "Google Search Console sites API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.Client.{Response, Transport}

  def list_sites(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.webmasters_request()
    |> Req.get(
      url: "/webmasters/v3/sites",
      params: sites_list_params(params)
    )
    |> Response.handle_site_list_response()
  end

  def add_site(%{site_url: site_url} = params, access_token)
      when is_binary(site_url) and is_binary(access_token) do
    encoded_url = URI.encode(site_url, &URI.char_unreserved?/1)

    access_token
    |> Transport.webmasters_request()
    |> Req.put(
      url: "/webmasters/v3/sites/#{encoded_url}",
      params: sites_add_params(params)
    )
    |> Response.handle_site_response()
  end

  defp sites_list_params(params) do
    %{}
    |> maybe_put(:fields, Data.get(params, :fields))
  end

  defp sites_add_params(params) do
    %{}
    |> maybe_put(:fields, Data.get(params, :fields))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
