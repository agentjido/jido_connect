defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.SubmitSitemap do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  @reason :invalid_sitemap_submit_request

  def run(input, %{credentials: credentials}) do
    with {:ok, site_url} <- validate_site_url(input),
         {:ok, sitemap_path} <- validate_sitemap_path(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.submit_sitemap(
             %{
               site_url: site_url,
               sitemap_path: sitemap_path
             }
             |> maybe_put(:fields, Data.get(input, :fields)),
             Map.get(credentials, :access_token)
           ) do
      {:ok, result}
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

  defp validate_sitemap_path(input) do
    case Data.get(input, :sitemap_path) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          validation_error("sitemap_path must be a non-empty URL",
            field: :sitemap_path
          )
        else
          {:ok, trimmed}
        end

      _missing ->
        validation_error("sitemap_path is required",
          field: :sitemap_path
        )
    end
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
