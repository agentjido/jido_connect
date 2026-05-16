defmodule Jido.Connect.Linear.ScopeResolver do
  @moduledoc """
  Resolves Linear OAuth scopes.

  Each action maps to the narrowest set of Linear scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "linear.issue.get" => ["read"],
    "linear.issue.search" => ["read"],
    "linear.issue.create" => ["write", "issues:create"],
    "linear.issue.update" => ["write"],
    "linear.issue.assign" => ["write"],
    "linear.issue.set_status" => ["write"],
    "linear.issue.set_labels" => ["write"],
    "linear.issue.comment.create" => ["write", "comments:create"],
    "linear.issue.comments.list" => ["read"],
    "linear.team.list" => ["read"],
    "linear.team.get" => ["read"],
    "linear.issue.changed" => ["read"]
  }

  @doc """
  Returns the least-privilege Linear scopes for the given operation.
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
