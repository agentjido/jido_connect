defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Search do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Searches for drive items matching a query across the authenticated user's OneDrive.

  Supports:
  - `query` (required) - the search text
  - `page_size` (default: 25) - maps to `$top`
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :query) do
      nil ->
        {:error, :query_required}

      query ->
        request = Transport.request(access_token)

        params =
          Pagination.query(%{q: query}, page_size: Map.get(input, :page_size, 25))

        url = "/me/drive/root/search(q='#{URI.encode_www_form(query)}')"

        case Transport.request(request, :get, url: url, params: params) do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.page(body, &Normalizer.drive_item/1) do
              {:ok, %{items: items, next_link: next_link}} ->
                {:ok, %{items: items, next_link: next_link}}

              {:error, _reason} = error ->
                error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to search Microsoft OneDrive items"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to search Microsoft OneDrive items"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
