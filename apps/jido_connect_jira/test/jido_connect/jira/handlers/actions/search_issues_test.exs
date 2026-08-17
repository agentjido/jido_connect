defmodule Jido.Connect.Jira.Handlers.Actions.SearchIssuesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.SearchIssues

  describe "run/2" do
    test "searches issues with JQL using mock client" do
      input = %{jql: "project = PROJ ORDER BY updated DESC"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = SearchIssues.run(input, runtime)
      assert length(result.issues) == 1
      assert hd(result.issues).key == "PROJ-123"
      assert result.total == 1
      assert result.start_at == 0
      assert result.max_results == 50
      assert result.is_last == true
    end

    test "passes pagination and field selection opts" do
      input = %{
        jql: "project = PROJ ORDER BY updated DESC",
        start_at: 0,
        max_results: 25,
        fields: ["summary", "status"]
      }

      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = SearchIssues.run(input, runtime)
      assert result.issues != []
    end
  end
end
