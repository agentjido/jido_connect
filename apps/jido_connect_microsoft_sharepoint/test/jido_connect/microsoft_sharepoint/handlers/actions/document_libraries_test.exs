defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DocumentLibrariesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.{
    CreateItem,
    DeleteItem,
    Delta,
    GetItem,
    ListItems,
    Search,
    UpdateItem,
    UploadItem
  }

  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{
    DownloadLibraryItem,
    ListLibraries
  }

  alias Jido.Connect.MicrosoftSharepoint.Previews.DocumentLibraryWrite

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)

    {:ok, context: %{credentials: %{access_token: "test-token"}}}
  end

  test "lists document libraries for a site", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/sites/site-1/drives"
      assert conn.query_params["$top"] == "10"

      Req.Test.json(conn, %{
        "value" => [%{"id" => "drive-1", "name" => "Documents", "driveType" => "documentLibrary"}]
      })
    end)

    assert {:ok, %{libraries: [library]}} =
             ListLibraries.run(%{site_id: "site-1", page_size: 10}, context)

    assert library.drive_id == "drive-1"
    assert library.drive_type == "documentLibrary"
  end

  test "reads and searches items through the shared drive runtime", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      assert String.starts_with?(conn.request_path, "/drives/drive-1/")

      cond do
        conn.request_path == "/drives/drive-1/root/children" ->
          Req.Test.json(conn, %{"value" => [item_payload()]})

        conn.request_path == "/drives/drive-1/items/item-1" ->
          Req.Test.json(conn, item_payload())

        String.contains?(conn.request_path, "/root/search(q='") ->
          assert conn.query_params["q"] == "report"
          Req.Test.json(conn, %{"value" => [item_payload()]})
      end
    end)

    assert {:ok, %{items: [item]}} = ListItems.run(%{drive_id: "drive-1"}, context)
    assert item.etag == "\"item-1,2\""

    assert {:ok, %{item: item}} =
             GetItem.run(%{drive_id: "drive-1", item_id: "item-1"}, context)

    assert item.name == "report.txt"

    assert {:ok, %{items: [item]}} =
             Search.run(%{drive_id: "drive-1", query: "report"}, context)

    assert item.item_id == "item-1"
  end

  test "downloads content and reads library delta", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/drives/drive-1/items/item-1/content" ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "text/plain; charset=utf-8")
          |> Plug.Conn.send_resp(200, "private file")

        "/drives/drive-1/root/delta" ->
          Req.Test.json(conn, %{
            "@odata.deltaLink" => "https://graph.test/drives/drive-1/root/delta?token=next",
            "value" => [item_payload()]
          })
      end
    end)

    assert {:ok, %{content: content}} =
             DownloadLibraryItem.run(%{drive_id: "drive-1", item_id: "item-1"}, context)

    assert content.content == "private file"
    assert content.mime_type == "text/plain"

    assert {:ok, %{items: [item], delta_link: delta_link}} =
             Delta.run(%{drive_id: "drive-1"}, context)

    assert item.item_id == "item-1"
    assert delta_link =~ "token=next"
  end

  test "creates, uploads, updates, and deletes library items", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/drives/drive-1/root/children"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"folder" => %{}, "name" => "Archive"}

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"id" => "folder-1", "name" => "Archive", "folder" => %{}})

        {"PUT", "/drives/drive-1/root:/report.txt:/content"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body == "private file"

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(item_payload())

        {"PATCH", "/drives/drive-1/items/item-1"} ->
          assert Plug.Conn.get_req_header(conn, "if-match") == ["\"item-1,2\""]
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "final.txt"}
          Req.Test.json(conn, %{item_payload() | "name" => "final.txt", "eTag" => "\"item-1,3\""})

        {"DELETE", "/drives/drive-1/items/item-1"} ->
          assert Plug.Conn.get_req_header(conn, "if-match") == ["\"item-1,3\""]
          Plug.Conn.send_resp(conn, 204, "")
      end
    end)

    assert {:ok, %{item: folder}} =
             CreateItem.run(%{drive_id: "drive-1", name: "Archive", type: "folder"}, context)

    assert folder.item_id == "folder-1"

    assert {:ok, %{item: uploaded}} =
             UploadItem.run(
               %{drive_id: "drive-1", name: "report.txt", content: "private file"},
               context
             )

    assert uploaded.item_id == "item-1"

    assert {:ok, %{item: updated}} =
             UpdateItem.run(
               %{
                 drive_id: "drive-1",
                 item_id: "item-1",
                 etag: "\"item-1,2\"",
                 name: "final.txt"
               },
               context
             )

    assert updated.etag == "\"item-1,3\""

    assert {:ok, %{deleted: true}} =
             DeleteItem.run(
               %{drive_id: "drive-1", item_id: "item-1", etag: "\"item-1,3\""},
               context
             )
  end

  test "normalizes errors and missing tokens", %{context: context} do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{"error" => %{"message" => "Access denied"}})
    end)

    assert {:error, %Error.ProviderError{provider: :microsoft, status: 403}} =
             ListLibraries.run(%{site_id: "site-1"}, context)

    assert {:error, :missing_access_token} = ListLibraries.run(%{}, %{})
    assert {:error, :missing_access_token} = DownloadLibraryItem.run(%{}, %{})
    assert {:error, :missing_access_token} = ListItems.run(%{}, %{})
  end

  test "write previews omit file content" do
    input = %{
      drive_id: "drive-1",
      item_id: "item-1",
      etag: "\"item-1,2\"",
      name: "report.txt",
      content: "private file"
    }

    preview = DocumentLibraryWrite.preview(input, %{})

    assert preview.drive_id == "drive-1"
    assert preview.item_id == "item-1"
    assert preview.content_size == 12
    refute inspect(preview) =~ "private file"
  end

  defp item_payload do
    %{
      "id" => "item-1",
      "eTag" => "\"item-1,2\"",
      "name" => "report.txt",
      "size" => 12,
      "file" => %{"mimeType" => "text/plain"}
    }
  end
end
