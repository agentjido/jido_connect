defmodule Jido.Connect.Notion.Client.PagesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Notion.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  describe "get_page/2" do
    test "sends GET /pages/:id and returns normalized page" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/pages/page-001"
        assert ["Bearer test-api-key"] = Plug.Conn.get_req_header(conn, "authorization")

        Req.Test.json(conn, %{
          "id" => "page-001",
          "created_time" => "2026-04-15T10:00:00.000Z",
          "last_edited_time" => "2026-05-10T14:30:00.000Z",
          "archived" => false,
          "url" => "https://www.notion.so/page-001",
          "properties" => %{
            "title" => %{
              "type" => "title",
              "title" => [%{"plain_text" => "Project Roadmap"}]
            }
          },
          "parent" => %{"type" => "workspace", "workspace" => true}
        })
      end)

      assert {:ok, page} = Client.get_page("page-001", "test-api-key")
      assert page.id == "page-001"
      assert page.url == "https://www.notion.so/page-001"
      assert page.archived == false
    end

    test "handles 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Could not find page with ID: page-missing"})
      end)

      assert {:error, error} = Client.get_page("page-missing", "test-api-key")
      assert Exception.message(error) =~ "Notion API request failed"
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"message" => "Unauthorized"})
      end)

      assert {:error, error} = Client.get_page("page-001", "bad-token")
      assert Exception.message(error) =~ "Notion API request failed"
    end
  end
end
