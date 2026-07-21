defmodule Jido.Connect.Notion.Handlers.Actions.UpdateBlockTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.UpdateBlock

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns updated block struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "block-001",
        "type" => "paragraph",
        "has_children" => false,
        "archived" => false,
        "parent" => %{"type" => "page_id", "page_id" => "page-001"},
        "paragraph" => %{
          "rich_text" => [%{"plain_text" => "Updated text"}],
          "color" => "default"
        }
      })
    end)

    assert {:ok, %{block: block}} =
             UpdateBlock.run(
               %{block_id: "block-001", archived: false},
               %{credentials: %{api_key: "test-key"}}
             )

    assert block.id == "block-001"
    assert block.archived == false
  end
end
