defmodule Jido.Connect.Google.Drive.Normalizer do
  @moduledoc "Normalizes Google Drive API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Drive.{Change, Channel, File, Folder, Permission, Revision}

  @folder_mime_type "application/vnd.google-apps.folder"

  @doc "Normalizes a Google Drive file payload."
  @spec file(map()) :: {:ok, File.t()} | {:error, term()}
  def file(payload) when is_map(payload) do
    with {:ok, permissions} <- normalize_embedded_permissions(Data.get(payload, "permissions")) do
      %{
        file_id: Data.get(payload, "id"),
        name: Data.get(payload, "name"),
        mime_type: Data.get(payload, "mimeType"),
        description: Data.get(payload, "description"),
        web_view_link: Data.get(payload, "webViewLink"),
        web_content_link: Data.get(payload, "webContentLink"),
        icon_link: Data.get(payload, "iconLink"),
        thumbnail_link: Data.get(payload, "thumbnailLink"),
        size: normalize_integer(Data.get(payload, "size")),
        md5_checksum: Data.get(payload, "md5Checksum"),
        created_time: Data.get(payload, "createdTime"),
        modified_time: Data.get(payload, "modifiedTime"),
        parents: Data.get(payload, "parents", []),
        owners: Data.get(payload, "owners", []),
        shared?: Data.get(payload, "shared", false),
        trashed?: Data.get(payload, "trashed", false),
        starred?: Data.get(payload, "starred", false),
        drive_id: Data.get(payload, "driveId"),
        permissions: permissions
      }
      |> Data.compact()
      |> File.new()
    end
  end

  def file(_payload), do: {:error, :invalid_file_payload}

  @doc "Normalizes a Google Drive folder payload."
  @spec folder(map()) :: {:ok, Folder.t()} | {:error, term()}
  def folder(payload) when is_map(payload) do
    %{
      folder_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      web_view_link: Data.get(payload, "webViewLink"),
      created_time: Data.get(payload, "createdTime"),
      modified_time: Data.get(payload, "modifiedTime"),
      parents: Data.get(payload, "parents", []),
      trashed?: Data.get(payload, "trashed", false),
      shared?: Data.get(payload, "shared", false),
      drive_id: Data.get(payload, "driveId")
    }
    |> Data.compact()
    |> Folder.new()
  end

  def folder(_payload), do: {:error, :invalid_folder_payload}

  @doc "Normalizes a Google Drive permission payload."
  @spec permission(map()) :: {:ok, Permission.t()} | {:error, term()}
  def permission(payload) when is_map(payload) do
    %{
      permission_id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      role: Data.get(payload, "role"),
      email_address: Data.get(payload, "emailAddress"),
      domain: Data.get(payload, "domain"),
      display_name: Data.get(payload, "displayName"),
      allow_file_discovery?: Data.get(payload, "allowFileDiscovery"),
      deleted?: Data.get(payload, "deleted", false),
      expiration_time: Data.get(payload, "expirationTime")
    }
    |> Data.compact()
    |> Permission.new()
  end

  def permission(_payload), do: {:error, :invalid_permission_payload}

  @doc "Normalizes a Google Drive change payload."
  @spec change(map()) :: {:ok, Change.t()} | {:error, term()}
  def change(payload) when is_map(payload) do
    with {:ok, file} <- normalize_change_file(Data.get(payload, "file")) do
      %{
        change_id: normalize_string(Data.get(payload, "changeId")),
        file_id: Data.get(payload, "fileId"),
        file: file,
        removed?: Data.get(payload, "removed", false),
        time: Data.get(payload, "time"),
        drive_id: Data.get(payload, "driveId"),
        change_type: Data.get(payload, "changeType")
      }
      |> Data.compact()
      |> Change.new()
    end
  end

  def change(_payload), do: {:error, :invalid_change_payload}

  @doc "Normalizes a Google Drive notification channel payload."
  @spec channel(map()) :: {:ok, Channel.t()} | {:error, term()}
  def channel(payload) when is_map(payload) do
    %{
      channel_id: Data.get(payload, "id"),
      resource_id: Data.get(payload, "resourceId"),
      resource_uri: Data.get(payload, "resourceUri"),
      token: Data.get(payload, "token"),
      expiration: normalize_string(Data.get(payload, "expiration")),
      type: Data.get(payload, "type"),
      address: Data.get(payload, "address"),
      kind: Data.get(payload, "kind"),
      payload?: Data.get(payload, "payload"),
      params: Data.get(payload, "params", %{})
    }
    |> Data.compact()
    |> Channel.new()
  end

  def channel(_payload), do: {:error, :invalid_channel_payload}

  @doc "Normalizes a Google Drive revision payload."
  @spec revision(map()) :: {:ok, Revision.t()} | {:error, term()}
  def revision(payload) when is_map(payload) do
    %{
      revision_id: Data.get(payload, "id"),
      mime_type: Data.get(payload, "mimeType"),
      kind: Data.get(payload, "kind"),
      published?: Data.get(payload, "published", false),
      keep_forever?: Data.get(payload, "keepForever", false),
      md5_checksum: Data.get(payload, "md5Checksum"),
      modified_time: Data.get(payload, "modifiedTime"),
      publish_auto?: Data.get(payload, "publishAuto", false),
      published_outside_domain?: Data.get(payload, "publishedOutsideDomain", false),
      published_link: Data.get(payload, "publishedLink"),
      size: normalize_integer(Data.get(payload, "size")),
      original_filename: Data.get(payload, "originalFilename"),
      last_modifying_user: Data.get(payload, "lastModifyingUser"),
      export_links: Data.get(payload, "exportLinks", %{})
    }
    |> Data.compact()
    |> Revision.new()
  end

  def revision(_payload), do: {:error, :invalid_revision_payload}

  @doc "Returns true when a Drive payload is a folder."
  @spec folder?(map()) :: boolean()
  def folder?(payload) when is_map(payload),
    do: Data.get(payload, "mimeType") == @folder_mime_type

  def folder?(_payload), do: false

  defp normalize_change_file(%{} = payload), do: file(payload)

  defp normalize_change_file(_payload), do: {:ok, nil}

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)

  defp normalize_embedded_permissions(nil), do: {:ok, []}
  defp normalize_embedded_permissions([]), do: {:ok, []}

  defp normalize_embedded_permissions(permissions) when is_list(permissions) do
    permissions
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case permission(payload) do
        {:ok, permission} -> {:cont, {:ok, [Map.from_struct(permission) | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, permissions} -> {:ok, Enum.reverse(permissions)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_embedded_permissions(_permissions), do: {:error, :invalid_permission_payload}
end
