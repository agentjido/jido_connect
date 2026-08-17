defmodule Jido.Connect.Jira.Handlers.Actions.UpdateIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.UpdateIssue

  describe "run/2" do
    test "updates an issue summary with mock client" do
      input = %{issue_key: "PROJ-123", summary: "Updated summary"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "updates multiple fields with mock client" do
      input = %{
        issue_key: "PROJ-123",
        summary: "Updated summary",
        priority: "High",
        labels: ["bug", "urgent"]
      }

      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "updates assignee with mock client" do
      input = %{issue_key: "PROJ-123", assignee_account_id: "acct-1"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end
  end
end
