defmodule Jido.Connect.Asana.Handlers.Actions.CreateStoryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.CreateStory

  describe "run/2" do
    test "creates a comment on a task with mock client" do
      input = %{task_gid: "998877", text: "Great progress on the design!"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = CreateStory.run(input, runtime)
      assert result.story.gid == "334456"
      assert result.story.resource_subtype == "comment_added"
      assert result.story.text == "Great progress on the design!"
      assert result.story.task_gid == "998877"
    end

    test "creates a pinned comment" do
      input = %{task_gid: "998877", text: "Important update", is_pinned: true}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = CreateStory.run(input, runtime)
      assert result.story.text == "Important update"
    end

    test "returns error for auth failure" do
      input = %{task_gid: "998877", text: "Comment"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = CreateStory.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
