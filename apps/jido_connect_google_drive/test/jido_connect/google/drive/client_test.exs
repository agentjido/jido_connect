defmodule Jido.Connect.Google.Drive.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Drive.{
    About,
    Change,
    Channel,
    Client,
    File,
    Folder,
    Permission,
    Revision
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "https://drive.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_drive, :google_drive_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["q"] == "mimeType = 'application/pdf'"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["spaces"] == "drive"

      Req.Test.json(conn, %{
        "files" => [
          %{
            "id" => "file123",
            "name" => "Budget.pdf",
            "mimeType" => "application/pdf",
            "parents" => ["folder123"]
          }
        ],
        "nextPageToken" => "next"
      })
    end)

    assert {:ok, %{files: [%File{} = file], next_page_token: "next"}} =
             Client.list_files(
               %{query: "mimeType = 'application/pdf'", page_size: 10, spaces: "drive"},
               "token"
             )

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
  end

  test "lists files with provider-specific filters" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files"

      assert conn.query_params["q"] ==
               "(mimeType = 'application/pdf') and (name contains 'Budget' and 'root' in parents and trashed = false)"

      Req.Test.json(conn, %{
        "files" => [
          %{
            "id" => "file123",
            "name" => "Budget.pdf",
            "mimeType" => "application/pdf"
          }
        ],
        "incompleteSearch" => true
      })
    end)

    assert {:ok, %{files: [%File{}], incomplete_search: true}} =
             Client.list_files(
               %{
                 query: "mimeType = 'application/pdf'",
                 filter: %{parent_id: "root", trashed: false, name_contains: "Budget"}
               },
               "token"
             )
  end

  test "returns provider errors for malformed Drive list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files"

      Req.Test.json(conn, %{
        "files" => [
          %{"id" => "file123"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_files(%{}, "token")
  end

  test "gets file metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["fields"] =~ "id,name,mimeType"

      Req.Test.json(conn, %{
        "id" => "file123",
        "name" => "Budget.pdf",
        "mimeType" => "application/pdf"
      })
    end)

    assert {:ok, %File{} = file} =
             Client.get_file(%{file_id: "file123", supports_all_drives: false}, "token")

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
  end

  test "gets Drive about metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/about"
      assert conn.query_params["fields"] =~ "storageQuota"

      Req.Test.json(conn, %{
        "user" => %{"emailAddress" => "owner@example.com"},
        "storageQuota" => %{"limit" => "1000", "usage" => "25"},
        "maxUploadSize" => "12345"
      })
    end)

    assert {:ok, %About{} = about} = Client.get_about(%{}, "token")
    assert about.user == %{"emailAddress" => "owner@example.com"}
    assert about.storage_quota == %{"limit" => "1000", "usage" => "25"}
  end

  test "returns provider errors for malformed Drive single-object responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"

      Req.Test.json(conn, %{
        "id" => "file123"
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_file(%{file_id: "file123"}, "token")
  end

  test "creates file metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Notes",
               "mimeType" => "text/plain",
               "parents" => ["folder123"]
             }

      Req.Test.json(conn, %{
        "id" => "created123",
        "name" => "Notes",
        "mimeType" => "text/plain",
        "parents" => ["folder123"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.create_file(
               %{name: "Notes", mime_type: "text/plain", parents: ["folder123"]},
               "token"
             )

    assert file.file_id == "created123"
    assert file.parents == ["folder123"]
  end

  test "creates folders" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Reports",
               "mimeType" => "application/vnd.google-apps.folder",
               "parents" => ["root"]
             }

      Req.Test.json(conn, %{
        "id" => "folder456",
        "name" => "Reports",
        "mimeType" => "application/vnd.google-apps.folder",
        "parents" => ["root"]
      })
    end)

    assert {:ok, %Folder{} = folder} =
             Client.create_folder(%{name: "Reports", parents: ["root"]}, "token")

    assert folder.folder_id == "folder456"
    assert folder.parents == ["root"]
  end

  test "copies files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/copy"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Budget Copy.pdf",
               "parents" => ["folder123"]
             }

      Req.Test.json(conn, %{
        "id" => "copy123",
        "name" => "Budget Copy.pdf",
        "mimeType" => "application/pdf",
        "parents" => ["folder123"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.copy_file(
               %{file_id: "file123", name: "Budget Copy.pdf", parents: ["folder123"]},
               "token"
             )

    assert file.file_id == "copy123"
    assert file.name == "Budget Copy.pdf"
  end

  test "updates files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["addParents"] == "folder456"
      assert conn.query_params["removeParents"] == "folder123"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"name" => "Renamed.pdf"}

      Req.Test.json(conn, %{
        "id" => "file123",
        "name" => "Renamed.pdf",
        "mimeType" => "application/pdf",
        "parents" => ["folder456"]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.update_file(
               %{
                 file_id: "file123",
                 name: "Renamed.pdf",
                 add_parents: "folder456",
                 remove_parents: "folder123"
               },
               "token"
             )

    assert file.name == "Renamed.pdf"
    assert file.parents == ["folder456"]
  end

  test "exports Google Workspace files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/export"
      assert conn.query_params["mimeType"] == "text/csv"
      assert Plug.Conn.get_req_header(conn, "accept") == ["text/csv"]

      conn
      |> Plug.Conn.put_resp_content_type("text/csv")
      |> Plug.Conn.resp(200, "name,total\nBudget,10\n")
    end)

    assert {:ok, content} =
             Client.export_file(%{file_id: "file123", mime_type: "text/csv"}, "token")

    assert content.file_id == "file123"
    assert content.mime_type == "text/csv"
    assert content.content == "name,total\nBudget,10\n"
    assert content.encoding == "utf-8"
    assert content.binary == false
  end

  test "downloads binary files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["alt"] == "media"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert Plug.Conn.get_req_header(conn, "accept") == ["*/*"]

      conn
      |> Plug.Conn.put_resp_content_type("application/pdf")
      |> Plug.Conn.resp(200, <<0, 1, 2>>)
    end)

    assert {:ok, content} =
             Client.download_file(%{file_id: "file123", supports_all_drives: true}, "token")

    assert content.file_id == "file123"
    assert content.mime_type == "application/pdf"
    assert content.content_base64 == "AAEC"
    assert content.encoding == "base64"
    assert content.binary == true
  end

  test "deletes files" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["supportsAllDrives"] == "true"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{file_id: "file123", deleted?: true}} =
             Client.delete_file(%{file_id: "file123", supports_all_drives: true}, "token")
  end

  test "lists file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/permissions"
      assert conn.query_params["pageSize"] == "50"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert conn.query_params["useDomainAdminAccess"] == "false"
      assert conn.query_params["fields"] =~ "permissions(id,type,role"

      Req.Test.json(conn, %{
        "permissions" => [
          %{
            "id" => "perm123",
            "type" => "user",
            "role" => "reader",
            "emailAddress" => "reader@example.com"
          }
        ],
        "nextPageToken" => "next-perm"
      })
    end)

    assert {:ok, %{permissions: [%Permission{} = permission], next_page_token: "next-perm"}} =
             Client.list_permissions(
               %{
                 file_id: "file123",
                 page_size: 50,
                 supports_all_drives: true,
                 use_domain_admin_access: false
               },
               "token"
             )

    assert permission.permission_id == "perm123"
    assert permission.email_address == "reader@example.com"
  end

  test "lists and gets file revisions" do
    Req.Test.stub(__MODULE__, fn
      %{request_path: "/v3/files/file123/revisions"} = conn ->
        assert conn.method == "GET"
        assert conn.query_params["pageSize"] == "50"
        assert conn.query_params["fields"] =~ "revisions(id,mimeType"

        Req.Test.json(conn, %{
          "revisions" => [
            %{
              "id" => "rev123",
              "mimeType" => "application/pdf",
              "modifiedTime" => "2026-05-05T12:00:00Z"
            }
          ],
          "nextPageToken" => "next-rev"
        })

      %{request_path: "/v3/files/file123/revisions/rev123"} = conn ->
        assert conn.method == "GET"
        assert conn.query_params["acknowledgeAbuse"] == "false"

        Req.Test.json(conn, %{
          "id" => "rev123",
          "mimeType" => "application/pdf",
          "modifiedTime" => "2026-05-05T12:00:00Z"
        })
    end)

    assert {:ok, %{revisions: [%Revision{} = revision], next_page_token: "next-rev"}} =
             Client.list_revisions(%{file_id: "file123", page_size: 50}, "token")

    assert revision.revision_id == "rev123"

    assert {:ok, %Revision{} = revision} =
             Client.get_revision(
               %{file_id: "file123", revision_id: "rev123", acknowledge_abuse: false},
               "token"
             )

    assert revision.revision_id == "rev123"
  end

  test "creates file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/permissions"
      assert conn.query_params["sendNotificationEmail"] == "false"
      assert conn.query_params["transferOwnership"] == "false"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "type" => "user",
               "role" => "reader",
               "emailAddress" => "reader@example.com"
             }

      Req.Test.json(conn, %{
        "id" => "perm456",
        "type" => "user",
        "role" => "reader",
        "emailAddress" => "reader@example.com"
      })
    end)

    assert {:ok, %Permission{} = permission} =
             Client.create_permission(
               %{
                 file_id: "file123",
                 type: "user",
                 role: "reader",
                 email_address: "reader@example.com",
                 send_notification_email: false,
                 transfer_ownership: false
               },
               "token"
             )

    assert permission.permission_id == "perm456"
    assert permission.role == "reader"
  end

  test "gets a change start page token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/changes/startPageToken"
      assert conn.query_params["supportsAllDrives"] == "true"

      Req.Test.json(conn, %{"startPageToken" => "start-token"})
    end)

    assert {:ok, %{start_page_token: "start-token"}} =
             Client.get_start_page_token(%{supports_all_drives: true}, "token")
  end

  test "lists file changes" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/changes"
      assert conn.query_params["pageToken"] == "start-token"
      assert conn.query_params["pageSize"] == "50"
      assert conn.query_params["includeRemoved"] == "true"
      assert conn.query_params["fields"] =~ "newStartPageToken,changes"

      Req.Test.json(conn, %{
        "changes" => [
          %{
            "changeId" => "change123",
            "fileId" => "file123",
            "removed" => false,
            "time" => "2026-05-05T12:00:00Z",
            "changeType" => "file",
            "file" => %{
              "id" => "file123",
              "name" => "Budget.pdf",
              "mimeType" => "application/pdf"
            }
          }
        ],
        "newStartPageToken" => "next-token"
      })
    end)

    assert {:ok, %{changes: [%Change{} = change], new_start_page_token: "next-token"}} =
             Client.list_changes(
               %{
                 page_token: "start-token",
                 page_size: 50,
                 include_removed: true
               },
               "token"
             )

    assert change.change_id == "change123"
    assert change.file.file_id == "file123"
  end

  test "creates and stops Drive watch channels" do
    Req.Test.stub(__MODULE__, fn
      %{request_path: "/v3/files/file123/watch"} = conn ->
        assert conn.method == "POST"
        assert conn.query_params["supportsAllDrives"] == "true"

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "id" => "channel123",
                 "type" => "web_hook",
                 "address" => "https://example.com/webhooks/drive",
                 "token" => "secret"
               }

        Req.Test.json(conn, %{
          "id" => "channel123",
          "resourceId" => "resource123",
          "resourceUri" => "https://www.googleapis.com/drive/v3/files/file123",
          "type" => "web_hook",
          "address" => "https://example.com/webhooks/drive"
        })

      %{request_path: "/v3/changes/watch"} = conn ->
        assert conn.method == "POST"
        assert conn.query_params["pageToken"] == "start-token"
        assert conn.query_params["includeRemoved"] == "true"

        Req.Test.json(conn, %{
          "id" => "channel456",
          "resourceId" => "resource456",
          "resourceUri" => "https://www.googleapis.com/drive/v3/changes",
          "type" => "web_hook",
          "address" => "https://example.com/webhooks/drive"
        })

      %{request_path: "/v3/channels/stop"} = conn ->
        assert conn.method == "POST"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"id" => "channel123", "resourceId" => "resource123"}

        Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %Channel{} = channel} =
             Client.watch_file(
               %{
                 file_id: "file123",
                 channel_id: "channel123",
                 address: "https://example.com/webhooks/drive",
                 type: "webhook",
                 token: "secret",
                 supports_all_drives: true
               },
               "token"
             )

    assert channel.channel_id == "channel123"

    assert {:ok, %Channel{} = channel} =
             Client.watch_changes(
               %{
                 page_token: "start-token",
                 channel_id: "channel456",
                 address: "https://example.com/webhooks/drive",
                 include_removed: true
               },
               "token"
             )

    assert channel.channel_id == "channel456"

    assert {:ok, %{channel_id: "channel123", resource_id: "resource123", stopped?: true}} =
             Client.stop_channel(%{channel_id: "channel123", resource_id: "resource123"}, "token")
  end
end
