defmodule Jido.Connect.Jira.Handlers.Actions.AssignIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.AssignIssue

  describe "run/2" do
    test "assigns an issue with mock client" do
      input = %{issue_key: "PROJ-123", account_id: "acct-1"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = AssignIssue.run(input, runtime)
      assert result.assigned == true
    end

    test "returns error when account_id is missing" do
      input = %{issue_key: "PROJ-123"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:error, error} = AssignIssue.run(input, runtime)
      assert error.reason == :invalid_assignee
    end

    test "returns error when account_id is empty" do
      input = %{issue_key: "PROJ-123", account_id: ""}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:error, error} = AssignIssue.run(input, runtime)
      assert error.reason == :invalid_assignee
    end
  end
end
