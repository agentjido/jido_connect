defmodule Jido.Connect.Asana.Handlers.Actions.AddTaskTagTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.AddTaskTag

  describe "run/2" do
    test "adds a tag to a task with mock client" do
      input = %{task_gid: "998877", tag_gid: "556677"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = AddTaskTag.run(input, runtime)
      assert result.result == %{}
    end

    test "returns error for auth failure" do
      input = %{task_gid: "998877", tag_gid: "556677"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = AddTaskTag.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
