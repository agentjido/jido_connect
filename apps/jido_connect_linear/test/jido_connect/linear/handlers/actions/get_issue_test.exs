defmodule Jido.Connect.Linear.Handlers.Actions.GetIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.GetIssue

  describe "run/2" do
    test "fetches an issue by ID with mock client" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, issue} = GetIssue.run(input, runtime)
      assert issue.identifier == "LIN-123"
      assert issue.title == "Test issue"
      assert issue.status.name == "In Progress"
      assert issue.team.key == "LIN"
    end
  end
end
