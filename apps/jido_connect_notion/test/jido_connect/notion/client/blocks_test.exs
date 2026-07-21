defmodule Jido.Connect.Notion.Client.BlocksTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "retrieve_block/2" do
    test "sends GET /blocks/:id and returns normalized block" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/blocks/block-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          "id" => "block-001",
          "type" => "paragraph",
          "has_children" => false,
          "archived" => false,
          "parent" => %{"type" => "page_id", "page_id" => "page-001"},
          "paragraph" => %{
            "rich_text" => [%{"plain_text" => "Hello world"}],
            "color" => "default"
          }
        })
      end)

      assert {:ok, block} = Client.retrieve_block("block-001", "test-api-key")
      assert block.id == "block-001"
      assert block.type == "paragraph"
      assert block.has_children == false
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find block"})
      end)

      assert {:error, error} = Client.retrieve_block("block-missing", "test-api-key")
      assert Exception.message(error) =~ "Notion API request failed"
    end
  end

  describe "list_block_children/3" do
    test "sends GET /blocks/:id/children and returns paginated blocks" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/blocks/block-001/children"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [
            %{
              "id" => "block-child-001",
              "type" => "paragraph",
              "has_children" => false,
              "paragraph" => %{
                "rich_text" => [%{"plain_text" => "Child paragraph"}],
                "color" => "default"
              }
            }
          ],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: results, has_more: false, next_cursor: nil}} =
               Client.list_block_children("block-001", %{}, "test-api-key")

      assert length(results) == 1
      assert Enum.at(results, 0).id == "block-child-001"
    end

    test "sends pagination params" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert %{
                 "page_size" => "5",
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
               Client.list_block_children(
                 "block-001",
                 %{page_size: 5, start_cursor: "cursor-abc"},
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
               Client.list_block_children("block-001", %{}, "bad-token")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
