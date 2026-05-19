defmodule Jido.Connect.Notion.Client.CommentsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "list_comments/2" do
    test "sends GET /comments with block_id and returns paginated comments" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/comments"

        assert %{
                 "block_id" => "page-001"
               } = URI.decode_query(conn.query_string)

        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [
            %{
              "id" => "comment-001",
              "discussion_id" => "discussion-001",
              "created_time" => "2026-05-01T09:00:00.000Z",
              "last_edited_time" => "2026-05-01T09:00:00.000Z",
              "created_by" => %{"id" => "user-001", "name" => "Alice"},
              "rich_text" => [%{"plain_text" => "Looks good"}],
              "parent" => %{"type" => "page_id", "page_id" => "page-001"}
            }
          ],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: results, has_more: false, next_cursor: nil}} =
               Client.list_comments(%{block_id: "page-001"}, "test-api-key")

      assert length(results) == 1
      assert Enum.at(results, 0).id == "comment-001"
      assert Enum.at(results, 0).created_by["name"] == "Alice"
    end

    test "sends pagination params" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert %{
                 "block_id" => "page-001",
                 "page_size" => "10",
                 "start_cursor" => "cursor-abc"
               } = URI.decode_query(conn.query_string)

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [],
          "has_more" => true,
          "next_cursor" => "cursor-def"
        })
      end)

      assert {:ok, %{has_more: true, next_cursor: "cursor-def"}} =
               Client.list_comments(
                 %{block_id: "page-001", page_size: 10, start_cursor: "cursor-abc"},
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
               Client.list_comments(%{block_id: "page-001"}, "bad-token")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
