defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermission do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Removes a permission from a Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id
  - `permission_id` (required) - the permission id to remove
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    item_id = Map.get(input, :item_id)
    permission_id = Map.get(input, :permission_id)

    case {item_id, permission_id} do
      {nil, _} ->
        {:error, :item_id_required}

      {_, nil} ->
        {:error, :permission_id_required}

      {item_id, permission_id} ->
        request = Transport.request(access_token)
        url = "/me/drive/items/#{item_id}/permissions/#{permission_id}"

        case Transport.request(request, :delete, url: url) do
          {:ok, %{status: 204}} ->
            {:ok, %{deleted: true, permission_id: permission_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to delete Microsoft OneDrive item permission"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to delete Microsoft OneDrive item permission"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
