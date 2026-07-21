defmodule Jido.Connect.Notion.Client.PagesWriteTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "create_page/2" do
    test "sends POST /pages with parent and properties" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/pages"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["parent"]["page_id"] == "page-parent"

        assert decoded["properties"]["title"]["title"] == [
                 %{"text" => %{"content" => "New Page"}}
               ]

        Req.Test.json(conn, %{
          "id" => "page-new",
          "archived" => false,
          "url" => "https://www.notion.so/page-new",
          "properties" => %{},
          "parent" => %{"type" => "page_id", "page_id" => "page-parent"}
        })
      end)

      assert {:ok, page} =
               Client.create_page(
                 %{
                   parent: %{page_id: "page-parent"},
                   properties: %{title: %{title: [%{text: %{content: "New Page"}}]}}
                 },
                 "test-api-key"
               )

      assert page.id == "page-new"
    end

    test "sends POST /pages with children blocks" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["children"]) == 1
        assert Enum.at(decoded["children"], 0)["type"] == "paragraph"

        Req.Test.json(conn, %{
          "id" => "page-new",
          "archived" => false,
          "url" => "https://www.notion.so/page-new",
          "properties" => %{},
          "parent" => %{"type" => "page_id", "page_id" => "page-parent"}
        })
      end)

      assert {:ok, page} =
               Client.create_page(
                 %{
                   parent: %{page_id: "page-parent"},
                   children: [%{type: "paragraph", paragraph: %{rich_text: []}}]
                 },
                 "test-api-key"
               )

      assert page.id == "page-new"
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"message" => "Unauthorized"})
      end)

      assert {:error, error} =
               Client.create_page(%{parent: %{page_id: "p"}}, "bad-token")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end

  describe "update_page/3" do
    test "sends PATCH /pages/:id with properties" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/pages/page-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["properties"]["Status"]["status"] == %{"name" => "Done"}

        Req.Test.json(conn, %{
          "id" => "page-001",
          "archived" => false,
          "url" => "https://www.notion.so/page-001",
          "properties" => %{},
          "parent" => %{"type" => "database_id", "database_id" => "db-001"}
        })
      end)

      assert {:ok, page} =
               Client.update_page(
                 "page-001",
                 %{properties: %{Status: %{status: %{name: "Done"}}}},
                 "test-api-key"
               )

      assert page.id == "page-001"
    end

    test "sends PATCH /pages/:id with archived true" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["archived"] == true

        Req.Test.json(conn, %{
          "id" => "page-001",
          "archived" => true,
          "url" => "https://www.notion.so/page-001",
          "properties" => %{},
          "parent" => %{"type" => "workspace", "workspace" => true}
        })
      end)

      assert {:ok, page} =
               Client.update_page("page-001", %{archived: true}, "test-api-key")

      assert page.archived == true
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find page"})
      end)

      assert {:error, error} =
               Client.update_page("page-missing", %{archived: true}, "test-api-key")

      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
