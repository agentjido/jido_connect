defmodule Jido.Connect.Google.Drive.Client do
  @moduledoc "Google Drive API client facade."

  alias Jido.Connect.Google.Drive.Client.{
    Changes,
    Channels,
    Comments,
    Files,
    Permissions,
    Replies,
    Revisions,
    SharedDrives
  }

  defdelegate list_files(params, access_token), to: Files
  defdelegate get_file(params, access_token), to: Files
  defdelegate create_file(params, access_token), to: Files
  defdelegate create_folder(params, access_token), to: Files
  defdelegate copy_file(params, access_token), to: Files
  defdelegate update_file(params, access_token), to: Files
  defdelegate export_file(params, access_token), to: Files
  defdelegate download_file(params, access_token), to: Files
  defdelegate delete_file(params, access_token), to: Files
  defdelegate list_permissions(params, access_token), to: Permissions
  defdelegate create_permission(params, access_token), to: Permissions
  defdelegate get_permission(params, access_token), to: Permissions
  defdelegate update_permission(params, access_token), to: Permissions
  defdelegate delete_permission(params, access_token), to: Permissions
  defdelegate list_revisions(params, access_token), to: Revisions
  defdelegate get_revision(params, access_token), to: Revisions
  defdelegate update_revision(params, access_token), to: Revisions
  defdelegate delete_revision(params, access_token), to: Revisions
  defdelegate list_comments(params, access_token), to: Comments
  defdelegate get_comment(params, access_token), to: Comments
  defdelegate create_comment(params, access_token), to: Comments
  defdelegate update_comment(params, access_token), to: Comments
  defdelegate delete_comment(params, access_token), to: Comments
  defdelegate list_replies(params, access_token), to: Replies
  defdelegate get_reply(params, access_token), to: Replies
  defdelegate create_reply(params, access_token), to: Replies
  defdelegate update_reply(params, access_token), to: Replies
  defdelegate delete_reply(params, access_token), to: Replies
  defdelegate list_shared_drives(params, access_token), to: SharedDrives
  defdelegate get_shared_drive(params, access_token), to: SharedDrives
  defdelegate create_shared_drive(params, access_token), to: SharedDrives
  defdelegate update_shared_drive(params, access_token), to: SharedDrives
  defdelegate delete_shared_drive(params, access_token), to: SharedDrives
  defdelegate hide_shared_drive(params, access_token), to: SharedDrives
  defdelegate unhide_shared_drive(params, access_token), to: SharedDrives
  defdelegate get_start_page_token(params, access_token), to: Changes
  defdelegate list_changes(params, access_token), to: Changes
  defdelegate watch_changes(params, access_token), to: Changes
  defdelegate watch_file(params, access_token), to: Files
  defdelegate stop_channel(params, access_token), to: Channels
end
