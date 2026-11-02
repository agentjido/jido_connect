defmodule Jido.Connect.Jira.Handlers.Actions.SearchIssuesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.SearchIssues

  describe "run/2" do
    test "searches issues with JQL using mock client" do
      input = %{jql: "project = PROJ ORDER BY updated DESC"}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = SearchIssues.run(input, runtime)
      assert [%{key: "PROJ-123"}] = result.issues
      assert %{next_page_token: "page-2", is_last: false, max_results: 50} = result
    end

    test "passes the page token, page size and field selection" do
      input = %{
        jql: "project = PROJ ORDER BY updated DESC",
        next_page_token: "page-2",
        max_results: 25,
        fields: ["summary", "status"]
      }

      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, %{is_last: true, next_page_token: nil, max_results: 25}} =
               SearchIssues.run(input, runtime)
    end
  end
end
