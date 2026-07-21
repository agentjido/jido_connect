defmodule Jido.Connect.Notion.Handlers.Actions.CreateCommentTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.CreateComment

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns comment struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "comment-002",
        "discussion_id" => "discussion-002",
        "created_by" => %{"id" => "user-001", "name" => "Alice"},
        "rich_text" => [%{"plain_text" => "Nice work"}],
        "parent" => %{"type" => "page_id", "page_id" => "page-001"}
      })
    end)

    assert {:ok, %{comment: comment}} =
             CreateComment.run(
               %{
                 parent: %{page_id: "page-001"},
                 rich_text: [%{text: %{content: "Nice work"}}]
               },
               %{credentials: %{api_key: "test-key"}}
             )

    assert comment.id == "comment-002"
  end
end
