defmodule Jido.Connect.Notion.Client.DatabasesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "get_database/2" do
    test "sends GET /databases/:id and returns normalized database" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/databases/db-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          "id" => "db-001",
          "created_time" => "2026-03-01T09:00:00.000Z",
          "title" => [%{"plain_text" => "Engineering Tasks"}],
          "properties" => %{
            "title" => %{"type" => "title"},
            "Status" => %{"type" => "status"}
          },
          "parent" => %{"type" => "page_id", "page_id" => "page-001"}
        })
      end)

      assert {:ok, db} = Client.get_database("db-001", "test-api-key")
      assert db.id == "db-001"
      assert length(db.title) == 1
      assert db.parent["page_id"] == "page-001"
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find database"})
      end)

      assert {:error, error} = Client.get_database("db-missing", "test-api-key")
      assert Exception.message(error) =~ "Notion API request failed"
    end
  end

  describe "query_database/3" do
    test "sends POST /databases/:id/query with filter and returns paginated results" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/databases/db-001/query"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["filter"]["property"] == "Status"
        assert decoded["filter"]["status"]["equals"] == "In Progress"

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
          "has_more" => true,
          "next_cursor" => "cursor-next"
        })
      end)

      assert {:ok, %{results: results, has_more: true, next_cursor: "cursor-next"}} =
               Client.query_database(
                 "db-001",
                 %{filter: %{property: "Status", status: %{equals: "In Progress"}}},
                 "test-api-key"
               )

      assert length(results) == 1
      assert Enum.at(results, 0).id == "page-001"
    end

    test "handles query with sorts" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["sorts"]) == 1
        assert Enum.at(decoded["sorts"], 0)["property"] == "Due Date"
        assert Enum.at(decoded["sorts"], 0)["direction"] == "ascending"

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: [], has_more: false}} =
               Client.query_database(
                 "db-001",
                 %{sorts: [%{property: "Due Date", direction: "ascending"}]},
                 "test-api-key"
               )
    end

    test "handles pagination with start_cursor" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["start_cursor"] == "cursor-abc"
        assert decoded["page_size"] == 5

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{has_more: false}} =
               Client.query_database(
                 "db-001",
                 %{start_cursor: "cursor-abc", page_size: 5},
                 "test-api-key"
               )
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"message" => "Unauthorized"})
      end)

      assert {:error, error} =
               Client.query_database("db-001", %{}, "bad-token")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
