defmodule Jido.Connect.Jira.Handlers.Actions.TransitionIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.TransitionIssue

  describe "run/2" do
    test "transitions an issue with mock client" do
      input = %{issue_key: "PROJ-123", transition_id: "21"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = TransitionIssue.run(input, runtime)
      assert result.transitioned == true
    end

    test "transitions an issue with fields" do
      input = %{
        issue_key: "PROJ-123",
        transition_id: "21",
        fields: %{resolution: %{name: "Done"}}
      }

      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = TransitionIssue.run(input, runtime)
      assert result.transitioned == true
    end
  end
end
