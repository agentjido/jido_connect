defmodule Jido.Connect.Google.SearchConsole.Client.SearchAnalytics do
  @moduledoc "Google Search Console search analytics API boundary."

  alias Jido.Connect.Google.SearchConsole.Client.{Response, Transport}

  def query_search_analytics(%{site_url: site_url, body: body}, access_token)
      when is_binary(site_url) and is_map(body) and is_binary(access_token) do
    encoded_url = URI.encode(site_url, &URI.char_unreserved?/1)

    access_token
    |> Transport.webmasters_request()
    |> Req.post(
      url: "/webmasters/v3/sites/#{encoded_url}/searchAnalytics/query",
      json: body
    )
    |> Response.handle_search_analytics_response()
  end
end
