defmodule Jido.Connect.Google.Drive.Client do
  @moduledoc "Google Drive API client facade."

  alias Jido.Connect.Google.Drive.Client.{Changes, Channels, Files, Permissions, Revisions}

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
  defdelegate get_start_page_token(params, access_token), to: Changes
  defdelegate list_changes(params, access_token), to: Changes
  defdelegate watch_changes(params, access_token), to: Changes
  defdelegate watch_file(params, access_token), to: Files
  defdelegate stop_channel(params, access_token), to: Channels
end
