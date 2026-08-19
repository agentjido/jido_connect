defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.DriveTarget

  @doc """
  Permanently deletes a Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id to delete
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :item_id) do
      nil ->
        {:error, :item_id_required}

      item_id ->
        with {:ok, url} <- DriveTarget.item(input, item_id) do
          request = Transport.request(access_token)

          case Transport.request(request, :delete, url: url, headers: etag_headers(input)) do
            {:ok, %{status: 204}} ->
              {:ok, %{deleted: true, item_id: item_id}}

            {:ok, response} ->
              Transport.handle_error_response({:ok, response},
                message: "Failed to delete Microsoft OneDrive item"
              )

            {:error, _reason} = error ->
              Transport.handle_error_response(error,
                message: "Failed to delete Microsoft OneDrive item"
              )
          end
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp etag_headers(input) do
    case Map.get(input, :etag) do
      etag when is_binary(etag) and etag != "" -> [{"if-match", etag}]
      _other -> []
    end
  end
end
