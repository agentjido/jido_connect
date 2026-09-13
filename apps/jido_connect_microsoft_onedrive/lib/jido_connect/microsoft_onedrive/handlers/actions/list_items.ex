defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOnedrive.{DriveTarget, Normalizer}

  @doc """
  Lists children of the authenticated user's OneDrive root or a specific folder.

  Supports:
  - `parent_id` (optional) - targets children of a specific folder item
  - `page_size` (default: 25) - maps to `$top`
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    with {:ok, url} <- DriveTarget.children(input, Map.get(input, :parent_id)) do
      request = Transport.request(access_token)
      params = Pagination.query(%{}, page_size: Map.get(input, :page_size, 25))

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
            message: "Failed to list Microsoft OneDrive items"
          )

        {:error, _reason} = error ->
          Transport.handle_error_response(error,
            message: "Failed to list Microsoft OneDrive items"
          )
      end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
