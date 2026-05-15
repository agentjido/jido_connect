defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.AddSite do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  @reason :invalid_site_add_request

  def run(input, %{credentials: credentials}) do
    with {:ok, site_url} <- validate_site_url(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.add_site(
             %{site_url: site_url}
             |> maybe_put(:fields, Data.get(input, :fields)),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{site: ResourceHelpers.public_map(result)}}
    end
  end

  defp validate_site_url(input) do
    case Data.get(input, :site_url) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          invalid_site_url()
        else
          if valid_site_url?(trimmed) do
            {:ok, trimmed}
          else
            {:error,
             Error.validation("site_url must be a valid URL or domain property",
               reason: @reason,
               details: %{field: :site_url, value: value}
             )}
          end
        end

      _missing ->
        invalid_site_url()
    end
  end

  defp valid_site_url?(url) do
    # Accept http/https URLs or domain properties like "sc-domain:example.com"
    String.starts_with?(url, "http://") or
      String.starts_with?(url, "https://") or
      String.starts_with?(url, "sc-domain:")
  end

  defp invalid_site_url do
    {:error,
     Error.validation("site_url must be a non-empty URL or domain property",
       reason: @reason,
       details: %{field: :site_url}
     )}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
