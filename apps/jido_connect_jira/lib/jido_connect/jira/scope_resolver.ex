defmodule Jido.Connect.Jira.ScopeResolver do
  @moduledoc """
  Resolves Jira OAuth scopes.

  Each action maps to the narrowest set of Atlassian Cloud scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "jira.issue.get" => ["read:jira-work"],
    "jira.issue.list" => ["read:jira-work"],
    "jira.issue.search" => ["read:jira-work"],
    "jira.issue.create" => ["write:jira-work"],
    "jira.issue.update" => ["write:jira-work"],
    "jira.issue.comment.list" => ["read:jira-work"],
    "jira.issue.comment.create" => ["write:jira-work"],
    "jira.project.list" => ["read:jira-work", "read:jira-configuration"],
    "jira.project.get" => ["read:jira-work", "read:jira-configuration"],
    "jira.field_schema.list" => ["read:jira-work", "read:jira-configuration"],
    "jira.user.list" => ["read:jira-users"]
  }

  @doc """
  Returns the least-privilege Atlassian Cloud scopes for the given operation.
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
