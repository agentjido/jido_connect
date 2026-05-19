defmodule Jido.Connect.Notion.Handlers.Actions.ListBlockChildrenTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.ListBlockChildren

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns paginated block children" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [
          %{
            "id" => "block-child-001",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{
              "rich_text" => [%{"plain_text" => "Child text"}],
              "color" => "default"
            }
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-next"
      })
    end)

    assert {:ok, %{results: results, has_more: true, next_cursor: "cursor-next"}} =
             ListBlockChildren.run(
               %{block_id: "block-001"},
               %{credentials: %{api_key: "test-key"}}
             )

    assert length(results) == 1
  end
end
