defmodule Jido.Connect.Google.Analytics.ScopeResolver do
  @moduledoc """
  Resolves Google Analytics scopes.

  The scaffold keeps Analytics scope behavior package-local so later action
  families can choose provider-specific least-privilege scopes without adding
  generic reporting scope logic to `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/analytics.readonly"

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> required_for_operation()
  end

  defp required_for_operation(_operation_id), do: [@readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
