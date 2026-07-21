defmodule Jido.Connect.Notion.Handlers.Actions.GetDatabaseTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.GetDatabase

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns database struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "db-001",
        "title" => [%{"plain_text" => "Tasks"}],
        "properties" => %{},
        "parent" => %{"type" => "page_id", "page_id" => "page-001"}
      })
    end)

    assert {:ok, %{database: db}} =
             GetDatabase.run(%{database_id: "db-001"}, %{credentials: %{api_key: "test-key"}})

    assert db.id == "db-001"
  end
end
