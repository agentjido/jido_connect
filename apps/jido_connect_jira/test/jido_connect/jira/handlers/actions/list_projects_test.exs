defmodule Jido.Connect.Jira.Handlers.Actions.ListProjectsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.ListProjects

  describe "run/2" do
    test "lists projects using mock client" do
      input = %{start_at: 0, max_results: 50}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = ListProjects.run(input, runtime)
      assert length(result.projects) == 2
      assert hd(result.projects).key == "PROJ"
      assert Enum.at(result.projects, 1).key == "TEAM"
      assert result.total == 2
      assert result.is_last == true
    end

    test "uses default pagination when not specified" do
      input = %{}
      runtime = Jido.Connect.Jira.TestRuntime.build()

      assert {:ok, result} = ListProjects.run(input, runtime)
      assert result.start_at == 0
      assert result.max_results == 50
    end
  end
end
