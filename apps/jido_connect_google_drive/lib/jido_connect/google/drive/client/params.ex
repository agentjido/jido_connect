defmodule Jido.Connect.Google.Drive.Client.Params do
  @moduledoc "Google Drive request parameter helpers."

  alias Jido.Connect.Data

  @default_file_fields [
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
  @default_permission_fields [
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
  @default_change_fields [
    "changeId",
    "fileId",
    "removed",
    "time",
    "driveId",
    "changeType",
    "file(#{Enum.join(@default_file_fields, ",")})"
  ]
  @default_revision_fields [
    "id",
    "mimeType",
    "modifiedTime",
    "keepForever",
    "published",
    "publishAuto",
    "publishedOutsideDomain",
    "lastModifyingUser",
    "originalFilename",
    "md5Checksum",
    "size",
    "exportLinks"
  ]
  @default_about_fields [
    "user",
    "storageQuota",
    "importFormats",
    "exportFormats",
    "maxUploadSize",
    "appInstalled",
    "folderColorPalette"
  ]

  @doc "Default file metadata fields used by read actions."
  def default_file_fields, do: Enum.join(@default_file_fields, ",")

  @doc "Default permission metadata fields used by permission actions."
  def default_permission_fields, do: Enum.join(@default_permission_fields, ",")

  @doc "Default change metadata fields used by Drive change pollers."
  def default_change_fields, do: Enum.join(@default_change_fields, ",")

  @doc "Default revision metadata fields used by revision read actions."
  def default_revision_fields, do: Enum.join(@default_revision_fields, ",")

  @doc "Default about fields used by Drive about reads."
  def default_about_fields, do: Enum.join(@default_about_fields, ",")

  @doc "Builds query params for `files.list`."
  def list_files_params(params) do
    %{
      q: Data.get(params, :query),
      pageSize: Data.get(params, :page_size, 25),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, list_fields()),
      orderBy: Data.get(params, :order_by),
      spaces: Data.get(params, :spaces, "drive"),
      corpora: Data.get(params, :corpora),
      driveId: Data.get(params, :drive_id),
      includeItemsFromAllDrives: Data.get(params, :include_items_from_all_drives),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `files.get`."
  def get_file_params(params) do
    %{
      fields: Data.get(params, :fields, default_file_fields()),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `about.get`."
  def about_params(params) do
    %{
      fields: Data.get(params, :fields, default_about_fields())
    }
    |> Data.compact()
  end

  @doc "Builds query params for `revisions.list`."
  def list_revisions_params(params) do
    %{
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, revision_list_fields())
    }
    |> Data.compact()
  end

  @doc "Builds query params for `revisions.get`."
  def get_revision_params(params) do
    %{
      fields: Data.get(params, :fields, default_revision_fields()),
      acknowledgeAbuse: Data.get(params, :acknowledge_abuse)
    }
    |> Data.compact()
  end

  @doc "Builds query params for file create/copy/update responses."
  def file_mutation_params(params) do
    %{
      fields: Data.get(params, :fields, default_file_fields()),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for metadata updates."
  def file_update_params(params) do
    params
    |> file_mutation_params()
    |> Map.merge(
      %{
        addParents: Data.get(params, :add_parents),
        removeParents: Data.get(params, :remove_parents)
      }
      |> Data.compact()
    )
  end

  @doc "Builds query params for Google Workspace file exports."
  def file_export_params(params) do
    %{
      mimeType: Data.get(params, :mime_type)
    }
    |> Data.compact()
  end

  @doc "Builds query params for raw file downloads."
  def file_download_params(params) do
    %{
      alt: "media",
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for file deletes."
  def file_delete_params(params) do
    %{
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds a metadata JSON body for file create/copy/update requests."
  def file_metadata_body(params) do
    %{
      name: Data.get(params, :name),
      mimeType: Data.get(params, :mime_type),
      description: Data.get(params, :description),
      parents: Data.get(params, :parents),
      starred: Data.get(params, :starred)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `permissions.list`."
  def list_permissions_params(params) do
    %{
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, permission_list_fields()),
      supportsAllDrives: Data.get(params, :supports_all_drives),
      useDomainAdminAccess: Data.get(params, :use_domain_admin_access)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `permissions.create`."
  def create_permission_params(params) do
    %{
      fields: Data.get(params, :fields, default_permission_fields()),
      sendNotificationEmail: Data.get(params, :send_notification_email),
      emailMessage: Data.get(params, :email_message),
      transferOwnership: Data.get(params, :transfer_ownership),
      supportsAllDrives: Data.get(params, :supports_all_drives),
      useDomainAdminAccess: Data.get(params, :use_domain_admin_access)
    }
    |> Data.compact()
  end

  @doc "Builds a JSON body for permission create requests."
  def permission_body(params) do
    %{
      type: Data.get(params, :type),
      role: Data.get(params, :role),
      emailAddress: Data.get(params, :email_address),
      domain: Data.get(params, :domain),
      allowFileDiscovery: Data.get(params, :allow_file_discovery),
      expirationTime: Data.get(params, :expiration_time)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `changes.getStartPageToken`."
  def start_page_token_params(params) do
    %{
      driveId: Data.get(params, :drive_id),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `changes.list`."
  def list_changes_params(params) do
    %{
      pageToken: Data.get(params, :page_token),
      pageSize: Data.get(params, :page_size, 100),
      fields: Data.get(params, :fields, change_list_fields()),
      spaces: Data.get(params, :spaces, "drive"),
      driveId: Data.get(params, :drive_id),
      includeItemsFromAllDrives: Data.get(params, :include_items_from_all_drives),
      includeRemoved: Data.get(params, :include_removed),
      restrictToMyDrive: Data.get(params, :restrict_to_my_drive),
      supportsAllDrives: Data.get(params, :supports_all_drives)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `files.watch`."
  def watch_file_params(params) do
    %{
      supportsAllDrives: Data.get(params, :supports_all_drives),
      acknowledgeAbuse: Data.get(params, :acknowledge_abuse),
      includePermissionsForView: Data.get(params, :include_permissions_for_view),
      includeLabels: Data.get(params, :include_labels)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `changes.watch`."
  def watch_changes_params(params) do
    %{
      pageToken: Data.get(params, :page_token),
      pageSize: Data.get(params, :page_size),
      spaces: Data.get(params, :spaces, "drive"),
      driveId: Data.get(params, :drive_id),
      includeCorpusRemovals: Data.get(params, :include_corpus_removals),
      includeItemsFromAllDrives: Data.get(params, :include_items_from_all_drives),
      includeRemoved: Data.get(params, :include_removed),
      restrictToMyDrive: Data.get(params, :restrict_to_my_drive),
      supportsAllDrives: Data.get(params, :supports_all_drives),
      includePermissionsForView: Data.get(params, :include_permissions_for_view),
      includeLabels: Data.get(params, :include_labels)
    }
    |> Data.compact()
  end

  @doc "Builds a JSON body for Drive notification channel watch requests."
  def channel_body(params) do
    %{
      id: Data.get(params, :channel_id),
      type: normalize_channel_type(Data.get(params, :type, "web_hook")),
      address: Data.get(params, :address),
      token: Data.get(params, :token),
      expiration: Data.get(params, :expiration),
      payload: Data.get(params, :payload),
      params: Data.get(params, :params)
    }
    |> Data.compact()
  end

  @doc "Builds a JSON body for `channels.stop`."
  def stop_channel_body(params) do
    %{
      id: Data.get(params, :channel_id),
      resourceId: Data.get(params, :resource_id)
    }
    |> Data.compact()
  end

  defp list_fields, do: "nextPageToken,incompleteSearch,files(#{default_file_fields()})"

  defp permission_list_fields,
    do: "nextPageToken,permissions(#{default_permission_fields()})"

  defp change_list_fields,
    do: "nextPageToken,newStartPageToken,changes(#{default_change_fields()})"

  defp revision_list_fields,
    do: "nextPageToken,revisions(#{default_revision_fields()})"

  defp normalize_channel_type("webhook"), do: "web_hook"
  defp normalize_channel_type(type), do: type
end
