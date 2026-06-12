defmodule Jido.Connect.Google.Drive.ScopeResolver do
  @moduledoc """
  Resolves Google Drive scopes.

  Drive metadata reads should prefer `drive.metadata.readonly`, while accepting
  broader read or app-file grants that hosts may already have.
  """

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @drive_scope "https://www.googleapis.com/auth/drive"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @write_actions [
    "google.drive.file.create",
    "google.drive.folder.create",
    "google.drive.file.copy",
    "google.drive.file.update",
    "google.drive.file.delete",
    "google.drive.permission.create",
    "google.drive.permission.update",
    "google.drive.permission.delete",
    "google.drive.revision.update",
    "google.drive.revision.delete",
    "google.drive.comment.create",
    "google.drive.comment.update",
    "google.drive.comment.delete",
    "google.drive.reply.create",
    "google.drive.reply.update",
    "google.drive.reply.delete"
  ]
  @shared_drive_admin_actions [
    "google.drive.shared_drive.create",
    "google.drive.shared_drive.update",
    "google.drive.shared_drive.delete",
    "google.drive.shared_drive.hide",
    "google.drive.shared_drive.unhide"
  ]
  @shared_drive_read_actions [
    "google.drive.shared_drives.list",
    "google.drive.shared_drive.get"
  ]
  @watch_actions [
    "google.drive.changes.watch",
    "google.drive.file.watch",
    "google.drive.channel.stop"
  ]
  @content_actions [
    "google.drive.file.export",
    "google.drive.file.download",
    "google.drive.comments.list",
    "google.drive.comment.get",
    "google.drive.replies.list",
    "google.drive.reply.get"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, connection) when operation_id in @write_actions,
    do: file_or_drive_scope(connection)

  defp required_for_operation(operation_id, _connection)
       when operation_id in @shared_drive_admin_actions,
       do: [@drive_scope]

  defp required_for_operation(operation_id, connection)
       when operation_id in @shared_drive_read_actions,
       do: readonly_or_drive_scope(connection)

  defp required_for_operation(operation_id, connection) when operation_id in @watch_actions,
    do: metadata_or_broader_scope(connection)

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @content_actions do
    cond do
      is_list(scopes) and @drive_scope in scopes -> [@drive_scope]
      is_list(scopes) and @readonly_scope in scopes -> [@readonly_scope]
      is_list(scopes) and @file_scope in scopes -> [@file_scope]
      true -> [@readonly_scope]
    end
  end

  defp required_for_operation(_operation_id, connection),
    do: metadata_or_broader_scope(connection)

  defp metadata_or_broader_scope(%{scopes: scopes}) when is_list(scopes) do
    cond do
      @drive_scope in scopes -> [@drive_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @file_scope in scopes -> [@file_scope]
      true -> [@metadata_scope]
    end
  end

  defp metadata_or_broader_scope(_connection), do: [@metadata_scope]

  defp readonly_or_drive_scope(%{scopes: scopes}) when is_list(scopes) do
    if @drive_scope in scopes do
      [@drive_scope]
    else
      [@readonly_scope]
    end
  end

  defp readonly_or_drive_scope(_connection), do: [@readonly_scope]

  defp file_or_drive_scope(%{scopes: scopes}) when is_list(scopes) do
    if @drive_scope in scopes do
      [@drive_scope]
    else
      [@file_scope]
    end
  end

  defp file_or_drive_scope(_connection), do: [@file_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
