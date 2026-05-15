defmodule Jido.Connect.Google.SearchConsole.Client.Sitemaps do
  @moduledoc "Google Search Console sitemaps API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.Client.{Response, Transport}

  def list_sitemaps(%{site_url: site_url} = params, access_token)
      when is_binary(site_url) and is_binary(access_token) do
    encoded_url = URI.encode(site_url, &URI.char_unreserved?/1)

    access_token
    |> Transport.webmasters_request()
    |> Req.get(
      url: "/webmasters/v3/sites/#{encoded_url}/sitemaps",
      params: sitemaps_list_params(params)
    )
    |> Response.handle_sitemap_list_response()
  end

  def submit_sitemap(%{site_url: site_url, sitemap_path: sitemap_path} = params, access_token)
      when is_binary(site_url) and is_binary(sitemap_path) and is_binary(access_token) do
    encoded_url = URI.encode(site_url, &URI.char_unreserved?/1)
    encoded_path = URI.encode(sitemap_path, &URI.char_unreserved?/1)

    access_token
    |> Transport.webmasters_request()
    |> Req.put(
      url: "/webmasters/v3/sites/#{encoded_url}/sitemaps/#{encoded_path}",
      params: sitemap_submit_params(params)
    )
    |> Response.handle_sitemap_submit_response(sitemap_path)
  end

  defp sitemaps_list_params(params) do
    %{}
    |> maybe_put(:sitemapIndex, Data.get(params, :sitemap_index))
  end

  defp sitemap_submit_params(params) do
    %{}
    |> maybe_put(:fields, Data.get(params, :fields))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
