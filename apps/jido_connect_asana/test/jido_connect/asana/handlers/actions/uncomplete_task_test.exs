defmodule Jido.Connect.Asana.Handlers.Actions.UncompleteTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.UncompleteTask

  describe "run/2" do
    test "uncompletes a task with mock client" do
      input = %{task_gid: "998877"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = UncompleteTask.run(input, runtime)
      assert result.task.gid == "998877"
      assert result.task.completed == false
    end

    test "returns error for not-found task" do
      input = %{task_gid: "unknown"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:error, error} = UncompleteTask.run(input, runtime)
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

      assert {:error, error} = UncompleteTask.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
