defmodule Jido.Connect.Notion.Handlers.Actions.AppendBlockChildrenTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.AppendBlockChildren

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns appended blocks" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [
          %{
            "id" => "block-new-001",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{
              "rich_text" => [%{"plain_text" => "New paragraph"}],
              "color" => "default"
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      })
    end)

    assert {:ok, %{results: results}} =
             AppendBlockChildren.run(
               %{
                 block_id: "block-001",
                 children: [%{type: "paragraph", paragraph: %{rich_text: []}}]
               },
               %{credentials: %{api_key: "test-key"}}
             )

    assert length(results) == 1
    assert Enum.at(results, 0).id == "block-new-001"
  end
end
