defmodule Jido.Connect.Google.Drive.Fields do
  @moduledoc """
  Provider-specific Google Drive field projection presets.

  Google Drive field expressions are not portable across providers. Hosts can
  discover whether a Drive action accepts `fields` through action or catalog
  metadata, then use these helpers when they want common Drive projections.
  """

  @file_metadata [
    "id",
    "name",
    "mimeType",
    "description",
    "webViewLink",
    "webContentLink",
    "iconLink",
    "thumbnailLink",
    "size",
    "md5Checksum",
    "createdTime",
    "modifiedTime",
    "parents",
    "owners",
    "shared",
    "trashed",
    "starred",
    "driveId"
  ]

  @permission_metadata [
    "id",
    "type",
    "role",
    "emailAddress",
    "domain",
    "displayName",
    "allowFileDiscovery",
    "deleted",
    "expirationTime"
  ]

  @permission_views ["published"]

  @doc "Google Drive permission views accepted by `includePermissionsForView`."
  def permission_views, do: @permission_views

  @doc "Default Drive file metadata fields for `files.get`."
  def file_metadata, do: join(@file_metadata)

  @doc "Default Drive permission metadata fields."
  def permission_metadata, do: join(@permission_metadata)

  @doc "Drive file metadata with embedded permission metadata."
  def file_with_permissions do
    join(@file_metadata ++ ["permissions(#{permission_metadata()})"])
  end

  @doc "Default `files.list` field expression."
  def file_list, do: "nextPageToken,files(#{file_metadata()})"

  @doc "Permission-aware `files.list` field expression."
  def file_list_with_permissions, do: "nextPageToken,files(#{file_with_permissions()})"

  @doc "Default `permissions.list` field expression."
  def permission_list, do: "nextPageToken,permissions(#{permission_metadata()})"

  @doc "Field presets for single-file metadata actions."
  def file_presets do
    %{
      default: file_metadata(),
      with_permissions: file_with_permissions()
    }
  end

  @doc "Field presets for `files.list`."
  def file_list_presets do
    %{
      default: file_list(),
      with_permissions: file_list_with_permissions()
    }
  end

  @doc "Field presets for single-permission actions."
  def permission_presets do
    %{
      default: permission_metadata()
    }
  end

  @doc "Field presets for `permissions.list`."
  def permission_list_presets do
    %{
      default: permission_list(),
      permission_metadata: permission_metadata()
    }
  end

  defp join(fields), do: Enum.join(fields, ",")
end
