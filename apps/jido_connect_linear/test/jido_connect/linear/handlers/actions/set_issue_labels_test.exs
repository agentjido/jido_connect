defmodule Jido.Connect.Linear.Handlers.Actions.SetIssueLabelsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.SetIssueLabels

  describe "run/2" do
    test "sets labels on an issue with mock client" do
      input = %{issue_id: "LIN-123", labels: ["bug", "urgent"]}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SetIssueLabels.run(input, runtime)
      assert result.updated == true
    end

    test "includes confirmation metadata in result" do
      input = %{issue_id: "LIN-123", labels: ["feature"]}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SetIssueLabels.run(input, runtime)
      assert result._confirmation.action == :labels_changed
      assert result._confirmation.issue_id == "LIN-123"
      assert result._confirmation.labels == ["feature"]
    end

    test "clears labels with empty list" do
      input = %{issue_id: "LIN-123", labels: []}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SetIssueLabels.run(input, runtime)
      assert result.updated == true
    end

    test "returns error when issue_id is missing" do
      input = %{labels: ["bug"]}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = SetIssueLabels.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when labels is missing" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = SetIssueLabels.run(input, runtime)
      assert error.reason == :invalid_labels
    end
  end
end
