defmodule Jido.Connect.Asana.ScopeResolver do
  @moduledoc """
  Resolves Asana scopes for action authorization.

  Asana scopes are flat strings (`default`, `read`, `write`).
  The resolver maps operation IDs to the minimum required scopes.
  """

  @scope_map %{
    # Read actions
    "asana.workspace.list" => ["default"],
    "asana.project.list" => ["default", "read"],
    "asana.task.list" => ["default", "read"],
    "asana.task.get" => ["default", "read"],
    "asana.task.search" => ["default", "read"],
    "asana.story.list" => ["default", "read"],
    "asana.user.get" => ["default", "read"],
    "asana.user.list" => ["default", "read"]
  }

  @spec required_scopes(term(), term(), term()) :: [String.t()]
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, ["default"]))
  end

  defp operation_id(nil), do: nil
  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
