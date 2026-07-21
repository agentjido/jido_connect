defmodule Jido.Connect.Asana.Handlers.Actions.UpdateTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.UpdateTask

  describe "run/2" do
    test "updates a task with mock client" do
      input = %{
        task_gid: "998877",
        name: "Updated task name",
        notes: "Updated notes"
      }

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = UpdateTask.run(input, runtime)
      assert result.task.gid == "998877"
      assert result.task.name == "Updated task name"
      assert result.task.notes == "Updated notes"
    end

    test "updates task completion status" do
      input = %{task_gid: "998877", completed: true}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = UpdateTask.run(input, runtime)
      assert result.task.gid == "998877"
      assert result.task.completed == true
    end

    test "returns error for not-found task" do
      input = %{task_gid: "unknown", name: "Doesn't matter"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:error, error} = UpdateTask.run(input, runtime)
      assert error.status == 404
      assert error.reason == :not_found
    end

    test "returns error for auth failure" do
      input = %{task_gid: "998877", name: "Updated"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = UpdateTask.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
