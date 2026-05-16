defmodule Jido.Connect.Linear.Handlers.Actions.CreateIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.CreateIssue

  describe "run/2" do
    test "creates an issue with mock client" do
      input = %{team_id: "team-1", title: "New issue"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, issue} = CreateIssue.run(input, runtime)
      assert issue.identifier == "LIN-124"
      assert issue.title == "New issue"
    end

    test "includes confirmation metadata in result" do
      input = %{team_id: "team-1", title: "New issue"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, issue} = CreateIssue.run(input, runtime)
      assert issue._confirmation.action == :created
      assert issue._confirmation.team_id == "team-1"
      assert issue._confirmation.title == "New issue"
    end

    test "creates an issue with optional fields" do
      input = %{
        team_id: "team-1",
        title: "Bug report",
        description: "Something broke",
        priority: "high",
        assignee_id: "user-1",
        labels: ["bug", "urgent"]
      }

      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, issue} = CreateIssue.run(input, runtime)
      assert issue.identifier == "LIN-124"
    end

    test "returns error when team_id is missing" do
      input = %{title: "New issue"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = CreateIssue.run(input, runtime)
      assert error.reason == :invalid_team_id
    end

    test "returns error when title is missing" do
      input = %{team_id: "team-1"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = CreateIssue.run(input, runtime)
      assert error.reason == :invalid_title
    end

    test "returns error when title is empty" do
      input = %{team_id: "team-1", title: ""}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = CreateIssue.run(input, runtime)
      assert error.reason == :invalid_title
    end
  end
end
