defmodule Jido.Connect.Asana.Handlers.Actions.ListTasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.ListTasks

  describe "run/2" do
    test "lists tasks with mock client" do
      input = %{}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTasks.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).gid == "998877"
      assert hd(result.items).name == "Design new landing page"
    end

    test "filters tasks by project" do
      input = %{project: "445566"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTasks.run(input, runtime)
      assert length(result.items) == 1
    end

    test "returns error for auth failure" do
      input = %{}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListTasks.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
