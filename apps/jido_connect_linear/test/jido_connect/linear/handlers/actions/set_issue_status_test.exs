defmodule Jido.Connect.Linear.Handlers.Actions.SetIssueStatusTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.SetIssueStatus

  describe "run/2" do
    test "changes issue status with mock client" do
      input = %{issue_id: "LIN-123", status: "started"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SetIssueStatus.run(input, runtime)
      assert result.updated == true
    end

    test "includes confirmation metadata in result" do
      input = %{issue_id: "LIN-123", status: "done"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SetIssueStatus.run(input, runtime)
      assert result._confirmation.action == :status_changed
      assert result._confirmation.issue_id == "LIN-123"
      assert result._confirmation.status == "done"
    end

    test "returns error when issue_id is missing" do
      input = %{status: "started"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = SetIssueStatus.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when status is missing" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = SetIssueStatus.run(input, runtime)
      assert error.reason == :invalid_status
    end

    test "returns error when status is empty" do
      input = %{issue_id: "LIN-123", status: ""}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = SetIssueStatus.run(input, runtime)
      assert error.reason == :invalid_status
    end
  end
end
