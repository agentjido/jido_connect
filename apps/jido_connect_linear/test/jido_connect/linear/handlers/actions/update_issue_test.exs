defmodule Jido.Connect.Linear.Handlers.Actions.UpdateIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.UpdateIssue

  describe "run/2" do
    test "updates an issue with mock client" do
      input = %{issue_id: "LIN-123", title: "Updated title"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = UpdateIssue.run(input, runtime)
      assert result.updated == true
    end
  end
end
