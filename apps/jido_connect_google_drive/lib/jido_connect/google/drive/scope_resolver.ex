defmodule Jido.Connect.Google.Drive.ScopeResolver do
  @moduledoc """
  Resolves Google Drive scopes.

  Drive metadata reads should prefer `drive.metadata.readonly`, while accepting
  broader read or app-file grants that hosts may already have.
  """

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @write_actions [
    "google.drive.file.create",
    "google.drive.folder.create",
    "google.drive.file.copy",
    "google.drive.file.update",
    "google.drive.file.delete",
    "google.drive.permission.create"
  ]
  @watch_actions [
    "google.drive.changes.watch",
    "google.drive.file.watch",
    "google.drive.channel.stop"
  ]
  @content_actions [
    "google.drive.file.export",
    "google.drive.file.download"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, _connection) when operation_id in @write_actions,
    do: [@file_scope]

  defp required_for_operation(operation_id, connection) when operation_id in @watch_actions,
    do: metadata_or_broader_scope(connection)

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @content_actions do
    cond do
      is_list(scopes) and @readonly_scope in scopes -> [@readonly_scope]
      is_list(scopes) and @file_scope in scopes -> [@file_scope]
      true -> [@readonly_scope]
    end
  end

  defp required_for_operation(_operation_id, connection),
    do: metadata_or_broader_scope(connection)

  defp metadata_or_broader_scope(%{scopes: scopes}) when is_list(scopes) do
    cond do
      @readonly_scope in scopes -> [@readonly_scope]
      @file_scope in scopes -> [@file_scope]
      true -> [@metadata_scope]
    end
  end

  defp metadata_or_broader_scope(_connection), do: [@metadata_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
