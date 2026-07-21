defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems do
  @moduledoc false

  alias Jido.Connect.Microsoft.{Pagination, Transport}
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Lists children of the authenticated user's OneDrive root or a specific folder.

  Supports:
  - `parent_id` (optional) - targets children of a specific folder item
  - `page_size` (default: 25) - maps to `$top`
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)
    url = children_url(Map.get(input, :parent_id))
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

  def run(_input, _context), do: {:error, :missing_access_token}

  defp children_url(nil), do: "/me/drive/root/children"
  defp children_url(parent_id), do: "/me/drive/items/#{parent_id}/children"
end
