defmodule Jido.Connect.Google.Drive.Handlers.Actions.UpdatePermission do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  @permission_roles ["owner", "organizer", "fileOrganizer", "writer", "commenter", "reader"]
  @mutable_fields [:role, :allow_file_discovery, :expiration_time, :remove_expiration]

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, permission} <-
           client.update_permission(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{permission: public_map(permission)}}
    end
  end

  defp validate_input(input) do
    with :ok <- validate_role(input),
         :ok <- validate_owner_transfer(input),
         :ok <- validate_has_mutation(input) do
      :ok
    end
  end

  defp validate_role(input) do
    case Data.get(input, :role) do
      nil ->
        :ok

      role when is_binary(role) ->
        role
        |> String.trim()
        |> validate_role_value(role)

      role ->
        validation_error("Invalid Google Drive permission role",
          field: :role,
          value: role,
          allowed: @permission_roles
        )
    end
  end

  defp validate_role_value(role, _raw_role) when role in @permission_roles, do: :ok

  defp validate_role_value(role, raw_role) do
    validation_error("Invalid Google Drive permission role",
      field: :role,
      value: raw_role,
      normalized_value: role,
      allowed: @permission_roles
    )
  end

  defp validate_owner_transfer(input) do
    if normalized_role(input) == "owner" and Data.get(input, :transfer_ownership) != true do
      validation_error("Owner permissions require transfer_ownership to be true",
        field: :transfer_ownership
      )
    else
      :ok
    end
  end

  defp validate_has_mutation(input) do
    if Enum.any?(@mutable_fields, &present?(input, &1)) do
      :ok
    else
      validation_error("Google Drive permission update requires mutable fields",
        field: :permission_update
      )
    end
  end

  defp present?(input, :remove_expiration), do: Data.get(input, :remove_expiration) == true

  defp present?(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> String.trim(value) != ""
      value -> value != nil
    end
  end

  defp normalized_role(input) do
    case Data.get(input, :role) do
      role when is_binary(role) -> String.trim(role)
      role -> role
    end
  end

  defp normalize_input(input) do
    input
    |> trim_string(:role)
    |> trim_string(:expiration_time)
    |> Map.put_new(:remove_expiration, false)
    |> Map.put_new(:transfer_ownership, false)
    |> Map.put_new(:supports_all_drives, false)
    |> Map.put_new(:use_domain_admin_access, false)
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end

  defp validation_error(message, details) do
    {:error, Error.validation(message, reason: :invalid_permission, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
