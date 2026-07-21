defmodule Jido.Connect.Asana.Handlers.Actions.RemoveTaskTagTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.RemoveTaskTag

  describe "run/2" do
    test "removes a tag from a task with mock client" do
      input = %{task_gid: "998877", tag_gid: "556677"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = RemoveTaskTag.run(input, runtime)
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

      assert {:error, error} = RemoveTaskTag.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
