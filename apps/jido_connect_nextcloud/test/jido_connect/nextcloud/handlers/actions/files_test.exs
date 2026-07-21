defmodule Jido.Connect.Nextcloud.Handlers.Actions.FilesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.Handlers.Actions.{
    CopyNode,
    CreateFolder,
    DeleteNode,
    DownloadFile,
    GetFile,
    ListFiles,
    MoveNode,
    SearchFiles,
    UploadFile
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_nextcloud, :nextcloud_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_nextcloud, :nextcloud_req_options)
    end)
  end

  test "lists files with WebDAV PROPFIND" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PROPFIND"
      assert Plug.Conn.get_req_header(conn, "depth") == ["1"]
      assert conn.request_path == "/remote.php/dav/files/alice/Documents"

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, dav_response())
    end)

    assert {:ok, %{nodes: [%{name: "report.txt"}]}} =
             ListFiles.run(%{path: "/Documents", depth: "1"}, runtime())
  end

  test "downloads file content" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/remote.php/dav/files/alice/report.txt"

      conn
      |> Plug.Conn.put_resp_header("etag", "\"abc\"")
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.resp(200, "hello")
    end)

    assert {:ok, %{content: "hello", content_type: "text/plain" <> _}} =
             DownloadFile.run(%{path: "/report.txt"}, runtime())
  end

  test "gets file metadata with depth zero PROPFIND" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PROPFIND"
      assert Plug.Conn.get_req_header(conn, "depth") == ["0"]
      assert conn.request_path == "/remote.php/dav/files/alice/Documents/report.txt"

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, dav_response())
    end)

    assert {:ok, %{node: %{name: "Documents"}}} =
             GetFile.run(%{path: "/Documents/report.txt"}, runtime())
  end

  test "searches files with WebDAV SEARCH" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "SEARCH"
      assert conn.request_path == "/remote.php/dav/"
      assert Req.Test.raw_body(conn) =~ "<d:literal>%report%</d:literal>"

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, dav_response())
    end)

    assert {:ok, %{nodes: [%{name: "Documents"}, %{name: "report.txt"}]}} =
             SearchFiles.run(%{query: "report", scope_path: "/Documents"}, runtime())
  end

  test "creates folder, uploads, and deletes" do
    Req.Test.stub(__MODULE__, fn
      %{method: "MKCOL"} = conn ->
        assert conn.request_path == "/remote.php/dav/files/alice/New"
        Plug.Conn.resp(conn, 201, "")

      %{method: "PUT"} = conn ->
        assert conn.request_path == "/remote.php/dav/files/alice/New/report.txt"
        Plug.Conn.resp(conn, 201, "")

      %{method: "DELETE"} = conn ->
        assert conn.request_path == "/remote.php/dav/files/alice/New/report.txt"
        Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{created: true}} = CreateFolder.run(%{path: "/New"}, runtime())

    assert {:ok, %{uploaded: true}} =
             UploadFile.run(%{path: "/New/report.txt", content: "hello"}, runtime())

    assert {:ok, %{deleted: true}} = DeleteNode.run(%{path: "/New/report.txt"}, runtime())
  end

  test "moves and copies nodes with destination headers" do
    Req.Test.stub(__MODULE__, fn
      %{method: "MOVE"} = conn ->
        assert conn.request_path == "/remote.php/dav/files/alice/old.txt"

        assert Plug.Conn.get_req_header(conn, "destination") == [
                 "https://cloud.example.com/remote.php/dav/files/alice/new.txt"
               ]

        assert Plug.Conn.get_req_header(conn, "overwrite") == ["T"]
        Plug.Conn.resp(conn, 201, "")

      %{method: "COPY"} = conn ->
        assert conn.request_path == "/remote.php/dav/files/alice/source.txt"

        assert Plug.Conn.get_req_header(conn, "destination") == [
                 "https://cloud.example.com/remote.php/dav/files/alice/copy.txt"
               ]

        assert Plug.Conn.get_req_header(conn, "overwrite") == ["F"]
        Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{moved: true, from_path: "/old.txt", to_path: "/new.txt"}} =
             MoveNode.run(
               %{from_path: "/old.txt", to_path: "/new.txt", overwrite: true},
               runtime()
             )

    assert {:ok, %{copied: true, from_path: "/source.txt", to_path: "/copy.txt"}} =
             CopyNode.run(%{from_path: "/source.txt", to_path: "/copy.txt"}, runtime())
  end

  defp runtime do
    %{
      credentials: %{
        base_url: "https://cloud.example.com",
        login_name: "alice",
        app_password: "secret"
      }
    }
  end

  defp dav_response do
    """
    <?xml version="1.0"?>
    <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
      <d:response>
        <d:href>/remote.php/dav/files/alice/Documents</d:href>
        <d:propstat><d:prop><d:displayname>Documents</d:displayname><d:resourcetype><d:collection /></d:resourcetype><oc:fileid>1</oc:fileid></d:prop></d:propstat>
      </d:response>
      <d:response>
        <d:href>/remote.php/dav/files/alice/Documents/report.txt</d:href>
        <d:propstat><d:prop><d:displayname>report.txt</d:displayname><d:getcontenttype>text/plain</d:getcontenttype><oc:fileid>2</oc:fileid></d:prop></d:propstat>
      </d:response>
    </d:multistatus>
    """
  end
end
