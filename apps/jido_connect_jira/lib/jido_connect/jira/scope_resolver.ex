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
    "jira.issue.transition" => ["write:jira-work"],
    "jira.issue.transition.list" => ["read:jira-work"],
    "jira.issue.delete" => ["write:jira-work"],
    "jira.issue.assign" => ["write:jira-work"],
    "jira.project.list" => ["read:jira-work", "read:jira-configuration"],
    "jira.project.get" => ["read:jira-work", "read:jira-configuration"],
    "jira.field_schema.list" => ["read:jira-work", "read:jira-configuration"],
    "jira.user.list" => ["read:jira-users"],
    "jira.board.list" => ["read:jira-work"],
    "jira.board.get" => ["read:jira-work"],
    "jira.board.create" => ["write:jira-work"],
    "jira.filter.list" => ["read:jira-work"],
    "jira.filter.get" => ["read:jira-work"],
    "jira.filter.create" => ["write:jira-work"],
    "jira.filter.update" => ["write:jira-work"],
    "jira.filter.columns.get" => ["read:jira-work"],
    "jira.filter.columns.update" => ["write:jira-work"],
    "jira.filter.share.update" => ["write:jira-work"],
    "jira.plan.list" => ["read:jira-work"],
    "jira.plan.get" => ["read:jira-work"],
    "jira.plan.create" => ["write:jira-work"],
    "jira.plan.update" => ["write:jira-work"],
    "jira.plan.duplicate" => ["write:jira-work"],
    "jira.plan.archive" => ["write:jira-work"],
    "jira.plan.trash" => ["write:jira-work"],
    "jira.issue.changed" => ["read:jira-work"],
    "jira.comment.changed" => ["read:jira-work"]
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
  defp operation_id(_operation), do: nil
end
