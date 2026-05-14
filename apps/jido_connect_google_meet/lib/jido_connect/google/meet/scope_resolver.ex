defmodule Jido.Connect.Google.Meet.ScopeResolver do
  @moduledoc """
  Resolves Google Meet scopes.

  The scaffold keeps Meet scope behavior package-local so later action families
  can choose provider-specific least-privilege scopes without adding generic
  Google scope logic to `jido_connect` core.
  """

  @created_scope "https://www.googleapis.com/auth/meetings.space.created"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @settings_scope "https://www.googleapis.com/auth/meetings.space.settings"
  @created_actions [
    "google.meet.space.create"
  ]
  @space_read_actions [
    "google.meet.space.get"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, _connection) when operation_id in @created_actions,
    do: [@created_scope]

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @space_read_actions and is_list(scopes) do
    cond do
      @readonly_scope in scopes -> [@readonly_scope]
      @created_scope in scopes -> [@created_scope]
      @settings_scope in scopes -> [@settings_scope]
      true -> [@readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _connection) when operation_id in @space_read_actions,
    do: [@readonly_scope]

  defp required_for_operation(_operation_id, _connection), do: [@readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
