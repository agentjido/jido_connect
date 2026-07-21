defmodule Jido.Connect.Notion.Handlers.Actions.CreatePageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.CreatePage

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns page struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "page-new",
        "archived" => false,
        "url" => "https://www.notion.so/page-new",
        "properties" => %{},
        "parent" => %{"type" => "page_id", "page_id" => "page-parent"}
      })
    end)

    assert {:ok, %{page: page}} =
             CreatePage.run(
               %{parent: %{page_id: "page-parent"}},
               %{credentials: %{api_key: "test-key"}}
             )

    assert page.id == "page-new"
    assert page.archived == false
  end
end
