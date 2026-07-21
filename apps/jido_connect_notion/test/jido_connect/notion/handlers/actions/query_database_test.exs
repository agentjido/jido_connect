defmodule Jido.Connect.Notion.Handlers.Actions.QueryDatabaseTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.QueryDatabase

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns paginated results" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [
          %{
            "object" => "page",
            "id" => "page-001",
            "archived" => false,
            "properties" => %{},
            "parent" => %{"type" => "database_id", "database_id" => "db-001"}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      })
    end)

    assert {:ok, %{results: results, has_more: false}} =
             QueryDatabase.run(
               %{database_id: "db-001", filter: %{property: "Status", status: %{equals: "Done"}}},
               %{credentials: %{api_key: "test-key"}}
             )

    assert length(results) == 1
  end
end
