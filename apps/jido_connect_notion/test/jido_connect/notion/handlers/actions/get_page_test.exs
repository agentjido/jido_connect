defmodule Jido.Connect.Notion.Handlers.Actions.GetPageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.GetPage

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
        "id" => "page-001",
        "archived" => false,
        "url" => "https://www.notion.so/page-001",
        "properties" => %{},
        "parent" => %{"type" => "workspace", "workspace" => true}
      })
    end)

    assert {:ok, %{page: page}} =
             GetPage.run(%{page_id: "page-001"}, %{credentials: %{api_key: "test-key"}})

    assert page.id == "page-001"
    assert page.archived == false
  end
end
