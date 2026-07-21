defmodule Jido.Connect.Jira.Handlers.Actions.GetProjectTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.GetProject

  describe "run/2" do
    test "fetches a project by key using mock client" do
      input = %{project_key: "PROJ"}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, project} = GetProject.run(input, runtime)
      assert project.key == "PROJ"
      assert project.name == "Project Alpha"
      assert project.project_type == "software"
      assert project.style == "classic"
    end
  end
end
