defmodule Jido.Connect.Jira.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.ScopeResolver

  test "resolves scopes for all expanded Jira action families" do
    read_actions = [
      "jira.board.list",
      "jira.board.get",
      "jira.filter.list",
      "jira.filter.get",
      "jira.filter.columns.get",
      "jira.issue.transition.list",
      "jira.plan.list",
      "jira.plan.get"
    ]

    write_actions = [
      "jira.board.create",
      "jira.filter.create",
      "jira.filter.update",
      "jira.filter.columns.update",
      "jira.filter.share.update",
      "jira.issue.delete",
      "jira.plan.create",
      "jira.plan.update",
      "jira.plan.duplicate",
      "jira.plan.archive",
      "jira.plan.trash"
    ]

    for action_id <- read_actions do
      assert ScopeResolver.required_scopes(%{id: action_id}, %{}, %{}) == ["read:jira-work"]
    end

    for action_id <- write_actions do
      assert ScopeResolver.required_scopes(%{action_id: action_id}, %{}, %{}) == [
               "write:jira-work"
             ]
    end
  end
end
