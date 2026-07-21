defmodule Jido.Connect.Asana.Handlers.Actions.GetTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.GetTask

  describe "run/2" do
    test "fetches a task by gid with mock client" do
      input = %{task_gid: "998877"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = GetTask.run(input, runtime)
      assert result.task.gid == "998877"
      assert result.task.name == "Design new landing page"
      assert result.task.completed == false
      assert result.task.due_on == "2026-07-15"
      assert result.task.assignee_gid == "123456"
    end

    test "returns error for not-found task" do
      input = %{task_gid: "unknown"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:error, error} = GetTask.run(input, runtime)
      assert error.status == 404
      assert error.reason == :not_found
    end

    test "returns error for auth failure" do
      input = %{task_gid: "998877"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = GetTask.run(input, runtime)
      assert error.status == 401
    end
  end
end
