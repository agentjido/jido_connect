defmodule Jido.Connect.Asana.Handlers.Actions.SearchTasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.SearchTasks

  describe "run/2" do
    test "searches tasks with query using mock client" do
      input = %{workspace_gid: "112233", query: "landing page"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchTasks.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).gid == "998877"
      assert hd(result.items).name == "Design new landing page"
    end

    test "returns all tasks when no query filter matches" do
      input = %{workspace_gid: "112233"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchTasks.run(input, runtime)
      assert length(result.items) == 2
    end

    test "returns error for auth failure" do
      input = %{workspace_gid: "112233", query: "test"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = SearchTasks.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
