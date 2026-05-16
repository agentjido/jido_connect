defmodule Jido.Connect.Jira.Handlers.Actions.GetIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.GetIssue

  describe "run/2" do
    test "fetches an issue by key with mock client" do
      input = %{issue_key: "PROJ-123"}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, issue} = GetIssue.run(input, runtime)
      assert issue.key == "PROJ-123"
      assert issue.id == "10001"
      assert issue.summary == "Test issue"
      assert issue.status.name == "In Progress"
      assert issue.project.key == "PROJ"
    end

    test "fetches an issue with field selection" do
      input = %{issue_key: "PROJ-123", fields: ["summary", "status"]}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, issue} = GetIssue.run(input, runtime)
      assert issue.key == "PROJ-123"
    end
  end
end
