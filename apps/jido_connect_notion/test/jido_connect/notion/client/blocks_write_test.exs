defmodule Jido.Connect.Notion.Client.BlocksWriteTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "append_block_children/3" do
    test "sends PATCH /blocks/:id/children with children" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/blocks/block-001/children"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["children"]) == 1
        assert Enum.at(decoded["children"], 0)["type"] == "paragraph"

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [
            %{
              "id" => "block-new-001",
              "type" => "paragraph",
              "has_children" => false,
              "paragraph" => %{
                "rich_text" => [%{"plain_text" => "New paragraph"}],
                "color" => "default"
              }
            }
          ],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: results}} =
               Client.append_block_children(
                 "block-001",
                 %{
                   children: [
                     %{
                       type: "paragraph",
                       paragraph: %{rich_text: [%{text: %{content: "New paragraph"}}]}
                     }
                   ]
                 },
                 "test-api-key"
               )

      assert length(results) == 1
      assert Enum.at(results, 0).id == "block-new-001"
    end

    test "sends after parameter for insert position" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["after"] == "block-existing"

        Req.Test.json(conn, %{
          "object" => "list",
          "results" => [],
          "has_more" => false,
          "next_cursor" => nil
        })
      end)

      assert {:ok, %{results: []}} =
               Client.append_block_children(
                 "block-001",
                 %{
                   children: [%{type: "paragraph", paragraph: %{rich_text: []}}],
                   after: "block-existing"
                 },
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
               Client.append_block_children("block-001", %{children: []}, "bad-token")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end

  describe "update_block/3" do
    test "sends PATCH /blocks/:id with archived true" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/blocks/block-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["archived"] == true

        Req.Test.json(conn, %{
          "id" => "block-001",
          "type" => "paragraph",
          "has_children" => false,
          "archived" => true,
          "parent" => %{"type" => "page_id", "page_id" => "page-001"},
          "paragraph" => %{
            "rich_text" => [%{"plain_text" => "Hello world"}],
            "color" => "default"
          }
        })
      end)

      assert {:ok, block} =
               Client.update_block("block-001", %{archived: true}, "test-api-key")

      assert block.archived == true
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find block"})
      end)

      assert {:error, error} =
               Client.update_block("block-missing", %{archived: true}, "test-api-key")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end

  describe "archive_block/2" do
    test "sends PATCH /blocks/:id with archived true" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/blocks/block-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["archived"] == true

        Req.Test.json(conn, %{
          "id" => "block-001",
          "type" => "paragraph",
          "has_children" => false,
          "archived" => true,
          "parent" => %{"type" => "page_id", "page_id" => "page-001"},
          "paragraph" => %{
            "rich_text" => [%{"plain_text" => "Hello world"}],
            "color" => "default"
          }
        })
      end)

      assert {:ok, block} = Client.archive_block("block-001", "test-api-key")
      assert block.archived == true
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find block"})
      end)

      assert {:error, error} = Client.archive_block("block-missing", "test-api-key")
      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
