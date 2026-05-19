defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreatePermission do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  @doc """
  Invites users or grants permission to a Microsoft OneDrive drive item.

  Supports:
  - `item_id` (required) - the drive item id
  - `recipients` (required) - list of %{email: "user@example.com"} maps
  - `roles` (required) - list of roles to grant (e.g. ["read"], ["write"])
  - `send_invitation` (optional, default true)
  - `message` (optional) - custom invitation email message
  - `require_sign_in` (optional, default true)
  - `expiration_date_time` (optional) - ISO 8601 expiration
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    item_id = Map.get(input, :item_id)
    recipients = Map.get(input, :recipients)
    roles = Map.get(input, :roles)

    case {item_id, recipients, roles} do
      {nil, _, _} ->
        {:error, :item_id_required}

      {_, nil, _} ->
        {:error, :recipients_required}

      {_, _, nil} ->
        {:error, :roles_required}

      {_, [], _} ->
        {:error, :recipients_required}

      {_, _, []} ->
        {:error, :roles_required}

      {item_id, recipients, roles} ->
        body = build_body(recipients, roles, input)
        request = Transport.request(access_token)
        url = "/me/drive/items/#{item_id}/invite"

        case Transport.request(request, :post, url: url, json: body) do
          {:ok, %{status: 200, body: resp_body}} when is_map(resp_body) ->
            case normalize_invite_response(resp_body) do
              {:ok, permissions} -> {:ok, %{permission: hd(permissions)}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to create Microsoft OneDrive item permission"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to create Microsoft OneDrive item permission"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_body(recipients, roles, input) do
    %{
      "recipients" => recipients,
      "roles" => roles,
      "sendInvitation" => Map.get(input, :send_invitation, true)
    }
    |> maybe_put("message", Map.get(input, :message))
    |> maybe_put("requireSignIn", Map.get(input, :require_sign_in))
    |> maybe_put("expirationDateTime", Map.get(input, :expiration_date_time))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_invite_response(%{"value" => values}) when is_list(values) do
    Normalizer.normalize_list(values, &Normalizer.permission/1)
  end

  defp normalize_invite_response(body) when is_map(body) do
    # Some responses return a single permission, not a list
    Normalizer.permission(body)
    |> case do
      {:ok, perm} -> {:ok, [perm]}
      error -> error
    end
  end
end
