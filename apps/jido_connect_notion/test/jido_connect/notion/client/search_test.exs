defmodule Jido.Connect.Notion.Client.SearchTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "search/2" do
    test "sends POST /search with query and returns normalized results" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/search"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["query"] == "project"
        assert decoded["filter"]["property"] == "object"
        assert decoded["filter"]["value"] == "page"

        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")
        assert ["2022-06-28"] = Plug.Conn.get_req_header(conn, "notion-version")

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [
            %{
              "object" => "page",
              "id" => "page-001",
              "created_time" => "2026-04-15T10:00:00.000Z",
              "last_edited_time" => "2026-05-10T14:30:00.000Z",
              "archived" => false,
              "url" => "https://www.notion.so/page-001",
              "properties" => %{},
              "parent" => %{"type" => "workspace", "workspace" => true}
            }
          ],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: results, has_more: false, next_cursor: nil}} =
               Client.search(
                 %{query: "project", filter: %{property: "object", value: "page"}},
                 "test-api-key"
               )

      assert length(results) == 1
      {:page, page} = Enum.at(results, 0)
      assert page.id == "page-001"
    end

    test "sends search with pagination cursor" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["start_cursor"] == "cursor-abc"
        assert decoded["page_size"] == 10

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [],
          "has_more" => true,
          "next_cursor" => "cursor-def"
        })
      end)

      assert {:ok, %{results: [], has_more: true, next_cursor: "cursor-def"}} =
               Client.search(%{start_cursor: "cursor-abc", page_size: 10}, "test-api-key")
    end

    test "returns mixed page and database results" do
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
            },
            %{
              "object" => "database",
              "id" => "db-001",
              "title" => [],
              "properties" => %{},
              "parent" => %{"type" => "workspace", "workspace" => true}
            }
          ],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: results}} =
               Client.search(%{query: "test"}, "test-api-key")

      assert length(results) == 2
      {:page, page} = Enum.at(results, 0)
      assert page.id == "page-001"
      {:database, db} = Enum.at(results, 1)
      assert db.id == "db-001"
    end

    test "handles 401 unauthorized error" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"message" => "Unauthorized"})
      end)

      assert {:error, error} = Client.search(%{}, "bad-token")
      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
