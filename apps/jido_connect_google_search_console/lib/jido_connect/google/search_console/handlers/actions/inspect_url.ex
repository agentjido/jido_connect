defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.InspectURL do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  @reason :invalid_url_inspection_request

  def run(input, %{credentials: credentials}) do
    with {:ok, site_url} <- validate_url(input, :site_url),
         {:ok, inspection_url} <- validate_url(input, :inspection_url),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.inspect_url(
             build_params(site_url, inspection_url, input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{inspection: ResourceHelpers.public_map(result)}}
    end
  end

  defp validate_url(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          validation_error("#{field} must be a non-empty URL",
            field: field
          )
        else
          {:ok, trimmed}
        end

      _missing ->
        validation_error("#{field} is required",
          field: field
        )
    end
  end

  defp build_params(site_url, inspection_url, input) do
    %{site_url: site_url, inspection_url: inspection_url}
    |> maybe_put(:language_code, Data.get(input, :language_code))
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
