defmodule Jido.Connect.Asana.Handlers.Actions.ListStoriesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.ListStories

  describe "run/2" do
    test "lists stories for a task with mock client" do
      input = %{task_gid: "998877"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListStories.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).gid == "334455"
      assert hd(result.items).resource_subtype == "comment_added"
      assert hd(result.items).text == "Updated the wireframes based on feedback."
    end

    test "returns empty list for task with no stories" do
      input = %{task_gid: "empty_task"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListStories.run(input, runtime)
      assert result.items == []
    end

    test "returns error for auth failure" do
      input = %{task_gid: "998877"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListStories.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
