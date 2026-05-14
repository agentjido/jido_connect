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

  @revision_metadata [
    "id",
    "mimeType",
    "kind",
    "published",
    "keepForever",
    "md5Checksum",
    "modifiedTime",
    "publishAuto",
    "publishedOutsideDomain",
    "publishedLink",
    "size",
    "originalFilename",
    "lastModifyingUser",
    "exportLinks"
  ]

  @reply_metadata [
    "id",
    "kind",
    "createdTime",
    "modifiedTime",
    "action",
    "author",
    "deleted",
    "htmlContent",
    "content"
  ]

  @comment_metadata [
    "id",
    "kind",
    "createdTime",
    "modifiedTime",
    "resolved",
    "anchor",
    "author",
    "deleted",
    "htmlContent",
    "content",
    "quotedFileContent",
    "replies(#{Enum.join(@reply_metadata, ",")})"
  ]

  @shared_drive_metadata [
    "id",
    "name",
    "kind",
    "colorRgb",
    "themeId",
    "backgroundImageLink",
    "backgroundImageFile",
    "createdTime",
    "hidden",
    "capabilities",
    "restrictions",
    "orgUnitId"
  ]

  @permission_views ["published"]

  @doc "Google Drive permission views accepted by `includePermissionsForView`."
  def permission_views, do: @permission_views

  @doc "Default Drive file metadata fields for `files.get`."
  def file_metadata, do: join(@file_metadata)

  @doc "Default Drive permission metadata fields."
  def permission_metadata, do: join(@permission_metadata)

  @doc "Default Drive revision metadata fields."
  def revision_metadata, do: join(@revision_metadata)

  @doc "Default Drive comment metadata fields."
  def comment_metadata, do: join(@comment_metadata)

  @doc "Default Drive reply metadata fields."
  def reply_metadata, do: join(@reply_metadata)

  @doc "Default Drive shared-drive metadata fields."
  def shared_drive_metadata, do: join(@shared_drive_metadata)

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

  @doc "Default `revisions.list` field expression."
  def revision_list, do: "nextPageToken,revisions(#{revision_metadata()})"

  @doc "Default `comments.list` field expression."
  def comment_list, do: "nextPageToken,comments(#{comment_metadata()})"

  @doc "Default `replies.list` field expression."
  def reply_list, do: "nextPageToken,replies(#{reply_metadata()})"

  @doc "Default `drives.list` field expression."
  def shared_drive_list, do: "nextPageToken,drives(#{shared_drive_metadata()})"

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

  @doc "Field presets for single-revision actions."
  def revision_presets do
    %{
      default: revision_metadata()
    }
  end

  @doc "Field presets for `revisions.list`."
  def revision_list_presets do
    %{
      default: revision_list(),
      revision_metadata: revision_metadata()
    }
  end

  @doc "Field presets for single-comment actions."
  def comment_presets do
    %{
      default: comment_metadata(),
      reply_metadata: reply_metadata()
    }
  end

  @doc "Field presets for `comments.list`."
  def comment_list_presets do
    %{
      default: comment_list(),
      comment_metadata: comment_metadata()
    }
  end

  @doc "Field presets for single-reply actions."
  def reply_presets do
    %{
      default: reply_metadata()
    }
  end

  @doc "Field presets for `replies.list`."
  def reply_list_presets do
    %{
      default: reply_list(),
      reply_metadata: reply_metadata()
    }
  end

  @doc "Field presets for single shared-drive actions."
  def shared_drive_presets do
    %{
      default: shared_drive_metadata()
    }
  end

  @doc "Field presets for `drives.list`."
  def shared_drive_list_presets do
    %{
      default: shared_drive_list(),
      shared_drive_metadata: shared_drive_metadata()
    }
  end

  defp join(fields), do: Enum.join(fields, ",")
end
