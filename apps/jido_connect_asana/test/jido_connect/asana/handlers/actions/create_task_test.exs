defmodule Jido.Connect.Asana.Handlers.Actions.CreateTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.CreateTask

  describe "run/2" do
    test "creates a task with mock client" do
      input = %{
        name: "New task",
        workspace_gid: "112233",
        notes: "Some notes",
        assignee: "123456",
        projects: ["445566"]
      }

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = CreateTask.run(input, runtime)
      assert result.task.gid == "998899"
      assert result.task.name == "New task"
      assert result.task.completed == false
      assert result.task.notes == "Some notes"
      assert result.task.assignee_gid == "123456"
      assert result.task.workspace_gid == "112233"
      assert result.task.project_gids == ["445566"]
    end

    test "creates a task with minimal fields" do
      input = %{name: "Minimal task", workspace_gid: "112233"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = CreateTask.run(input, runtime)
      assert result.task.name == "Minimal task"
      assert result.task.workspace_gid == "112233"
    end

    test "returns error for auth failure" do
      input = %{name: "Task", workspace_gid: "112233"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = CreateTask.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
