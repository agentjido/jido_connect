defmodule Jido.Connect.MicrosoftOnedrive.ScopeResolver do
  @moduledoc """
  Resolves Microsoft OneDrive scopes for dynamic least-privilege checks.

  Maps action ids to the narrowest required Microsoft Graph files scope,
  accepting broader already-granted scopes when the host connection includes
  them.
  """

  @files_read "Files.Read"
  @files_read_all "Files.Read.All"
  @files_read_write "Files.ReadWrite"
  @files_read_write_all "Files.ReadWrite.All"

  @read_actions [
    "microsoft.onedrive.items.list",
    "microsoft.onedrive.item.get",
    "microsoft.onedrive.drive.get",
    "microsoft.onedrive.items.search",
    "microsoft.onedrive.item.download",
    "microsoft.onedrive.items.delta"
  ]

  @read_all_actions [
    "microsoft.onedrive.drives.list"
  ]

  @write_actions [
    "microsoft.onedrive.item.create",
    "microsoft.onedrive.item.update",
    "microsoft.onedrive.item.upload"
  ]

  @destructive_actions [
    "microsoft.onedrive.item.delete",
    "microsoft.onedrive.item.permission.delete"
  ]

  @sharing_read_actions [
    "microsoft.onedrive.item.permissions.list",
    "microsoft.onedrive.item.permission.get"
  ]

  @sharing_write_actions [
    "microsoft.onedrive.item.create_link",
    "microsoft.onedrive.item.permission.create"
  ]

  @doc "Returns the required Microsoft Graph scopes for the given operation."
  @spec required_scopes(map(), map(), map()) :: [String.t()]
  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @write_actions and is_list(scopes) do
    cond do
      @files_read_write in scopes -> [@files_read_write]
      @files_read_write_all in scopes -> [@files_read_write_all]
      true -> [@files_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @destructive_actions and is_list(scopes) do
    cond do
      @files_read_write in scopes -> [@files_read_write]
      @files_read_write_all in scopes -> [@files_read_write_all]
      true -> [@files_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @sharing_write_actions and is_list(scopes) do
    cond do
      @files_read_write in scopes -> [@files_read_write]
      @files_read_write_all in scopes -> [@files_read_write_all]
      true -> [@files_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @sharing_read_actions and is_list(scopes) do
    cond do
      @files_read in scopes -> [@files_read]
      @files_read_all in scopes -> [@files_read_all]
      @files_read_write in scopes -> [@files_read_write]
      @files_read_write_all in scopes -> [@files_read_write_all]
      true -> [@files_read]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @read_actions and is_list(scopes) do
    cond do
      @files_read in scopes -> [@files_read]
      @files_read_all in scopes -> [@files_read_all]
      @files_read_write in scopes -> [@files_read_write]
      @files_read_write_all in scopes -> [@files_read_write_all]
      true -> [@files_read]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @write_actions,
       do: [@files_read_write]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @destructive_actions,
       do: [@files_read_write]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @sharing_write_actions,
       do: [@files_read_write]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @sharing_read_actions,
       do: [@files_read]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @read_all_actions,
       do: [@files_read_all]

  defp required_for_operation(_operation_id, _connection),
    do: [@files_read]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
