defmodule Jido.Connect.Calendly.ScopeResolver do
  @moduledoc """
  Resolves Calendly OAuth scopes.

  Calendly uses a small set of scopes (`view`, `edit`, `webhook`). The scaffold
  keeps scope behavior package-local so later action families can choose
  provider-specific least-privilege scopes.
  """

  @scope_map %{}

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
