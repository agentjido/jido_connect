defmodule Jido.Connect.MicrosoftOutlook.ScopeResolver do
  @moduledoc """
  Resolves Microsoft Outlook Mail scopes for dynamic least-privilege checks.

  Maps action ids to the narrowest required Microsoft Graph mail scope,
  accepting broader already-granted scopes when the host connection includes
  them.
  """

  @mail_read "Mail.Read"
  @mail_read_basic "Mail.ReadBasic"
  @mail_read_write "Mail.ReadWrite"
  @mail_send "Mail.Send"

  @read_actions [
    "microsoft.outlook.profile.get",
    "microsoft.outlook.messages.list",
    "microsoft.outlook.message.get",
    "microsoft.outlook.folders.list",
    "microsoft.outlook.folder.get"
  ]

  @send_actions [
    "microsoft.outlook.message.send",
    "microsoft.outlook.draft.create",
    "microsoft.outlook.draft.update",
    "microsoft.outlook.draft.send",
    "microsoft.outlook.message.reply",
    "microsoft.outlook.message.reply_all"
  ]

  @mutation_actions [
    "microsoft.outlook.message.move",
    "microsoft.outlook.message.delete",
    "microsoft.outlook.draft.delete"
  ]

  @doc "Returns the required Microsoft Graph scopes for the given operation."
  @spec required_scopes(map(), map(), map()) :: [String.t()]
  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @send_actions and is_list(scopes) do
    cond do
      @mail_send in scopes -> [@mail_send]
      @mail_read_write in scopes -> [@mail_read_write]
      true -> [@mail_send]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @mutation_actions and is_list(scopes) do
    cond do
      @mail_read_write in scopes -> [@mail_read_write]
      true -> [@mail_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @read_actions and is_list(scopes) do
    cond do
      @mail_read in scopes -> [@mail_read]
      @mail_read_write in scopes -> [@mail_read_write]
      @mail_read_basic in scopes -> [@mail_read_basic]
      true -> [@mail_read]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @send_actions,
       do: [@mail_send]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @mutation_actions,
       do: [@mail_read_write]

  defp required_for_operation(_operation_id, _connection),
    do: [@mail_read]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
