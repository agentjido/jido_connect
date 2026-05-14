defmodule Jido.Connect.Google.Meet.ScopeResolver do
  @moduledoc """
  Resolves Google Meet scopes.

  The scaffold keeps Meet scope behavior package-local so later action families
  can choose provider-specific least-privilege scopes without adding generic
  Google scope logic to `jido_connect` core.
  """

  @created_scope "https://www.googleapis.com/auth/meetings.space.created"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @created_actions [
    "google.meet.space.create"
  ]

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> required_for_operation()
  end

  defp required_for_operation(operation_id) when operation_id in @created_actions,
    do: [@created_scope]

  defp required_for_operation(_operation_id), do: [@readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
