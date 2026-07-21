defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLink do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Creates a sharing link for a Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id
  - `type` (required) - link type: "view", "edit", or "embed"
  - `scope` (optional) - link scope: "anonymous", "organization", "users"
  - `password` (optional) - password for the link
  - `expiration_date_time` (optional) - ISO 8601 expiration
  - `retain_inherited_permissions` (optional, default true)
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :item_id) do
      nil ->
        {:error, :item_id_required}

      item_id ->
        body = build_body(input)
        request = Transport.request(access_token)
        url = "/me/drive/items/#{item_id}/createLink"

        case Transport.request(request, :post, url: url, json: body) do
          {:ok, %{status: 201, body: resp_body}} when is_map(resp_body) ->
            case Normalizer.permission(resp_body) do
              {:ok, permission} -> {:ok, %{permission: permission}}
              {:error, _reason} = error -> error
            end

          {:ok, %{status: 200, body: resp_body}} when is_map(resp_body) ->
            case Normalizer.permission(resp_body) do
              {:ok, permission} -> {:ok, %{permission: permission}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to create Microsoft OneDrive sharing link"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to create Microsoft OneDrive sharing link"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_body(input) do
    %{"type" => Map.get(input, :type, "view")}
    |> maybe_put("scope", Map.get(input, :scope))
    |> maybe_put("password", Map.get(input, :password))
    |> maybe_put("expirationDateTime", Map.get(input, :expiration_date_time))
    |> Map.put("retainInheritedPermissions", Map.get(input, :retain_inherited_permissions, true))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
