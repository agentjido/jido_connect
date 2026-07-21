defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetPermission do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Fetches a specific permission for a Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id
  - `permission_id` (required) - the permission id
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

        case Transport.request(request, :get, url: url) do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.permission(body) do
              {:ok, permission} -> {:ok, %{permission: permission}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Microsoft OneDrive item permission"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to get Microsoft OneDrive item permission"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
