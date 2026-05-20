defmodule Jido.Connect.GitLab.ScopeResolver do
  @moduledoc """
  Resolves GitLab OAuth/PAT scopes.

  Each action maps to the narrowest set of GitLab API scopes required.
  The resolver is consulted by the `access` block at runtime.

  This is a shell implementation. Scope mappings will be populated as
  action fragments are added in subsequent waves.
  """

  @scope_map %{}

  @doc """
  Returns the least-privilege GitLab scopes for the given operation.
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
