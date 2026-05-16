defmodule Jido.Connect.Linear.Handlers.Actions.UpdateIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.UpdateIssue

  describe "run/2" do
    test "updates an issue title with mock client" do
      input = %{issue_id: "LIN-123", title: "Updated title"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "includes confirmation metadata in result" do
      input = %{issue_id: "LIN-123", title: "Updated title"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result._confirmation.action == :updated
      assert result._confirmation.issue_id == "LIN-123"
    end

    test "updates multiple fields with mock client" do
      input = %{
        issue_id: "LIN-123",
        title: "Updated summary",
        priority: "high",
        labels: ["bug", "urgent"]
      }

      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "updates status with mock client" do
      input = %{issue_id: "LIN-123", status: "started"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "updates assignee with mock client" do
      input = %{issue_id: "LIN-123", assignee_id: "user-2"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end

    test "returns error when issue_id is missing" do
      input = %{title: "Updated title"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = UpdateIssue.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when issue_id is empty" do
      input = %{issue_id: "", title: "Updated title"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = UpdateIssue.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when no update fields provided" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = UpdateIssue.run(input, runtime)
      assert error.reason == :no_update_fields
    end
  end
end
