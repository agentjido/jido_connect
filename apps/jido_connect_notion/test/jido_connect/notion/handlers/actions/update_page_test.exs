defmodule Jido.Connect.Notion.Handlers.Actions.UpdatePageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.UpdatePage

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns updated page struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "page-001",
        "archived" => true,
        "url" => "https://www.notion.so/page-001",
        "properties" => %{},
        "parent" => %{"type" => "workspace", "workspace" => true}
      })
    end)

    assert {:ok, %{page: page}} =
             UpdatePage.run(
               %{page_id: "page-001", archived: true},
               %{credentials: %{api_key: "test-key"}}
             )

    assert page.id == "page-001"
    assert page.archived == true
  end
end
