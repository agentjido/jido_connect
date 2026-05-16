defmodule Jido.Connect.Linear.Handlers.Actions.AssignIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.AssignIssue

  describe "run/2" do
    test "assigns an issue with mock client" do
      input = %{issue_id: "LIN-123", assignee_id: "user-2"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = AssignIssue.run(input, runtime)
      assert result.updated == true
    end

    test "includes confirmation metadata in result" do
      input = %{issue_id: "LIN-123", assignee_id: "user-2"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = AssignIssue.run(input, runtime)
      assert result._confirmation.action == :assigned
      assert result._confirmation.issue_id == "LIN-123"
      assert result._confirmation.assignee_id == "user-2"
    end

    test "returns error when issue_id is missing" do
      input = %{assignee_id: "user-2"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AssignIssue.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when assignee_id is missing" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AssignIssue.run(input, runtime)
      assert error.reason == :invalid_assignee_id
    end

    test "returns error when assignee_id is empty" do
      input = %{issue_id: "LIN-123", assignee_id: ""}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AssignIssue.run(input, runtime)
      assert error.reason == :invalid_assignee_id
    end
  end
end
