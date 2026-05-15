defmodule Jido.Connect.HubSpot.ScopeResolver do
  @moduledoc """
  Resolves HubSpot OAuth scopes.

  The scaffold keeps HubSpot scope behavior package-local so later action
  families can choose provider-specific least-privilege scopes without adding
  generic CRM scope logic to `jido_connect` core.
  """

  @scope_map %{}

  @doc """
  Returns the least-privilege HubSpot scopes for the given operation.

  The scaffold starts with an empty scope map. Action fragments populate
  entries as they are added.
  """
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
