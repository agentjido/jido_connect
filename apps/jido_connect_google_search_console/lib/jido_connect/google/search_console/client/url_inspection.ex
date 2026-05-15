defmodule Jido.Connect.Google.SearchConsole.Client.URLInspection do
  @moduledoc "Google Search Console URL inspection API boundary."

  alias Jido.Connect.Google.SearchConsole.Client.{Response, Transport}

  def inspect_url(%{site_url: site_url, inspection_url: inspection_url} = params, access_token)
      when is_binary(site_url) and is_binary(inspection_url) and is_binary(access_token) do
    body =
      %{
        "siteUrl" => site_url,
        "inspectionUrl" => inspection_url
      }
      |> maybe_put("languageCode", Map.get(params, :language_code))

    access_token
    |> Transport.search_console_request()
    |> Req.post(
      url: "/v1/urlInspection/index:inspect",
      json: body
    )
    |> Response.handle_url_inspection_response()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
