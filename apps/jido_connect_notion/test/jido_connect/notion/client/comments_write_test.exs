defmodule Jido.Connect.Notion.Client.CommentsWriteTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "create_comment/2" do
    test "sends POST /comments with parent and rich_text" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/comments"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["parent"]["page_id"] == "page-001"
        assert length(decoded["rich_text"]) == 1
        assert Enum.at(decoded["rich_text"], 0)["text"]["content"] == "Great work"

        Req.Test.json(conn, %{
          "id" => "comment-002",
          "discussion_id" => "discussion-002",
          "created_time" => "2026-05-19T10:00:00.000Z",
          "last_edited_time" => "2026-05-19T10:00:00.000Z",
          "created_by" => %{"id" => "user-001", "name" => "Alice"},
          "rich_text" => [%{"plain_text" => "Great work"}],
          "parent" => %{"type" => "page_id", "page_id" => "page-001"}
        })
      end)

      assert {:ok, comment} =
               Client.create_comment(
                 %{
                   parent: %{page_id: "page-001"},
                   rich_text: [%{text: %{content: "Great work"}}]
                 },
                 "test-api-key"
               )

      assert comment.id == "comment-002"
    end

    test "sends POST /comments with discussion_id for reply" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["discussion_id"] == "discussion-001"
        assert is_nil(decoded["parent"])

        Req.Test.json(conn, %{
          "id" => "comment-003",
          "discussion_id" => "discussion-001",
          "created_time" => "2026-05-19T10:00:00.000Z",
          "last_edited_time" => "2026-05-19T10:00:00.000Z",
          "created_by" => %{"id" => "user-002", "name" => "Bob"},
          "rich_text" => [%{"plain_text" => "Reply"}],
          "parent" => %{"type" => "discussion_id", "discussion_id" => "discussion-001"}
        })
      end)

      assert {:ok, comment} =
               Client.create_comment(
                 %{
                   discussion_id: "discussion-001",
                   rich_text: [%{text: %{content: "Reply"}}]
                 },
                 "test-api-key"
               )

      assert comment.id == "comment-003"
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"message" => "Unauthorized"})
      end)

      assert {:error, error} =
               Client.create_comment(
                 %{parent: %{page_id: "p"}, rich_text: [%{text: %{content: "hi"}}]},
                 "bad-token"
               )

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
