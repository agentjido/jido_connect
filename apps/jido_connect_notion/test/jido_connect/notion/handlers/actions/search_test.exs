defmodule Jido.Connect.Notion.Handlers.Actions.SearchTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Handlers.Actions.Search

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 delegates to default client" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [
          %{
            "object" => "page",
            "id" => "page-001",
            "archived" => false,
            "properties" => %{},
            "parent" => %{"type" => "workspace", "workspace" => true}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      })
    end)

    assert {:ok, %{results: results, has_more: false}} =
             Search.run(%{query: "test"}, %{credentials: %{api_key: "test-key"}})

    assert length(results) == 1
  end

  test "run/2 delegates to injected client" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "object" => "list",
        "results" => [],
        "has_more" => false,
        "next_cursor" => nil
      })
    end)

    assert {:ok, %{results: []}} =
             Search.run(%{query: "empty"}, %{
               credentials: %{api_key: "test-key", notion_client: Jido.Connect.Notion.Client}
             })
  end
end
