defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSitemaps do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  @reason :invalid_sitemap_list_request

  def run(input, %{credentials: credentials}) do
    with {:ok, site_url} <- validate_site_url(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_sitemaps(
             normalize_input(input, site_url),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         sitemaps: Enum.map(Map.get(result, :sitemaps, []), &ResourceHelpers.public_map/1)
       }}
    end
  end

  defp validate_site_url(input) do
    case Data.get(input, :site_url) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          validation_error("site_url must be a non-empty URL or domain property",
            field: :site_url
          )
        else
          {:ok, trimmed}
        end

      _missing ->
        validation_error("site_url is required",
          field: :site_url
        )
    end
  end

  defp normalize_input(input, site_url) do
    %{site_url: site_url}
    |> maybe_put(:sitemap_index, Data.get(input, :sitemap_index))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp validation_error(message, opts) do
    field = Keyword.get(opts, :field)

    {:error,
     Error.validation(message,
       reason: @reason,
       details: %{field: field}
     )}
  end
end
