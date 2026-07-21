defmodule Jido.Connect.Notion.Handlers.Actions.ArchiveBlockTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.ArchiveBlock

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns archived block struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "block-001",
        "type" => "paragraph",
        "has_children" => false,
        "archived" => true,
        "parent" => %{"type" => "page_id", "page_id" => "page-001"},
        "paragraph" => %{
          "rich_text" => [%{"plain_text" => "Archived"}],
          "color" => "default"
        }
      })
    end)

    assert {:ok, %{block: block}} =
             ArchiveBlock.run(
               %{block_id: "block-001"},
               %{credentials: %{api_key: "test-key"}}
             )

    assert block.id == "block-001"
    assert block.archived == true
  end
end
