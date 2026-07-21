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
    "asana.user.list" => ["default", "read"],
    # Write actions
    "asana.task.create" => ["write"],
    "asana.task.update" => ["write"],
    "asana.task.complete" => ["write"],
    "asana.task.uncomplete" => ["write"],
    "asana.task.add_project" => ["write"],
    "asana.task.remove_project" => ["write"],
    "asana.task.add_tag" => ["write"],
    "asana.task.remove_tag" => ["write"],
    "asana.story.create" => ["write"],
    # Triggers
    "asana.task.changed" => ["default", "read"],
    "asana.task.added" => ["default", "read"],
    "asana.task.deleted" => ["default", "read"],
    "asana.project.changed" => ["default", "read"]
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
  defp operation_id(_operation), do: nil
end
