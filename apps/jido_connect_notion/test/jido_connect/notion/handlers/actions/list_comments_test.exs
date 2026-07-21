defmodule Jido.Connect.Notion.Handlers.Actions.ListCommentsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.ListComments

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns paginated comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [
          %{
            "id" => "comment-001",
            "discussion_id" => "discussion-001",
            "created_by" => %{"id" => "user-001", "name" => "Alice"},
            "rich_text" => [%{"plain_text" => "Nice work"}],
            "parent" => %{"type" => "page_id", "page_id" => "page-001"}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      })
    end)

    assert {:ok, %{results: results, has_more: false}} =
             ListComments.run(
               %{block_id: "page-001"},
               %{credentials: %{api_key: "test-key"}}
             )

    assert length(results) == 1
    assert Enum.at(results, 0).id == "comment-001"
  end
end
