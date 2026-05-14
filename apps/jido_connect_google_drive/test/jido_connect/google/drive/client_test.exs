defmodule Jido.Connect.Google.Drive.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Drive.{
    Change,
    Channel,
    Client,
    Comment,
    Fields,
    File,
    Folder,
    Permission,
    Reply,
    SharedDrive,
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

  test "passes permission-aware file fields and normalizes embedded permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files"
      assert conn.query_params["fields"] == Fields.file_list_with_permissions()
      assert conn.query_params["includePermissionsForView"] == "published"

      Req.Test.json(conn, %{
        "files" => [
          %{
            "id" => "file123",
            "name" => "Budget.pdf",
            "mimeType" => "application/pdf",
            "permissions" => [
              %{
                "id" => "perm123",
                "type" => "user",
                "role" => "reader",
                "emailAddress" => "reader@example.com"
              }
            ]
          }
        ]
      })
    end)

    assert {:ok, %{files: [%File{} = file]}} =
             Client.list_files(
               %{
                 fields: Fields.file_list_with_permissions(),
                 include_permissions_for_view: "published"
               },
               "token"
             )

    assert [
             %{
               permission_id: "perm123",
               type: "user",
               role: "reader",
               email_address: "reader@example.com"
             }
           ] = file.permissions
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

  test "passes custom get file fields unchanged" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123"
      assert conn.query_params["fields"] == Fields.file_with_permissions()
      assert conn.query_params["includePermissionsForView"] == "published"

      Req.Test.json(conn, %{
        "id" => "file123",
        "name" => "Budget.pdf",
        "permissions" => [
          %{
            "id" => "perm123",
            "type" => "anyone",
            "role" => "reader",
            "allowFileDiscovery" => false
          }
        ]
      })
    end)

    assert {:ok, %File{} = file} =
             Client.get_file(
               %{
                 file_id: "file123",
                 fields: Fields.file_with_permissions(),
                 include_permissions_for_view: "published"
               },
               "token"
             )

    assert [%{permission_id: "perm123", type: "anyone", role: "reader"}] = file.permissions
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
      assert conn.query_params["fields"] == Fields.permission_list()

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

  test "gets file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/permissions/perm123"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert conn.query_params["useDomainAdminAccess"] == "true"
      assert conn.query_params["fields"] == Fields.permission_metadata()

      Req.Test.json(conn, %{
        "id" => "perm123",
        "type" => "user",
        "role" => "reader",
        "emailAddress" => "reader@example.com"
      })
    end)

    assert {:ok, %Permission{} = permission} =
             Client.get_permission(
               %{
                 file_id: "file123",
                 permission_id: "perm123",
                 supports_all_drives: true,
                 use_domain_admin_access: true
               },
               "token"
             )

    assert permission.permission_id == "perm123"
    assert permission.role == "reader"
  end

  test "updates file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123/permissions/perm123"
      assert conn.query_params["removeExpiration"] == "true"
      assert conn.query_params["transferOwnership"] == "false"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "writer",
               "allowFileDiscovery" => false
             }

      Req.Test.json(conn, %{
        "id" => "perm123",
        "type" => "user",
        "role" => "writer",
        "emailAddress" => "reader@example.com"
      })
    end)

    assert {:ok, %Permission{} = permission} =
             Client.update_permission(
               %{
                 file_id: "file123",
                 permission_id: "perm123",
                 role: "writer",
                 allow_file_discovery: false,
                 remove_expiration: true,
                 transfer_ownership: false
               },
               "token"
             )

    assert permission.permission_id == "perm123"
    assert permission.role == "writer"
  end

  test "deletes file permissions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123/permissions/perm123"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert conn.query_params["useDomainAdminAccess"] == "false"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{file_id: "file123", permission_id: "perm123", deleted?: true}} =
             Client.delete_permission(
               %{
                 file_id: "file123",
                 permission_id: "perm123",
                 supports_all_drives: true,
                 use_domain_admin_access: false
               },
               "token"
             )
  end

  test "lists file revisions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/revisions"
      assert conn.query_params["pageSize"] == "25"
      assert conn.query_params["pageToken"] == "page-1"
      assert conn.query_params["fields"] == Fields.revision_list()

      Req.Test.json(conn, %{
        "revisions" => [
          %{
            "id" => "rev1",
            "mimeType" => "application/pdf",
            "keepForever" => true,
            "modifiedTime" => "2026-05-05T12:00:00Z"
          }
        ],
        "nextPageToken" => "next-rev"
      })
    end)

    assert {:ok, %{revisions: [%Revision{} = revision], next_page_token: "next-rev"}} =
             Client.list_revisions(
               %{file_id: "file123", page_size: 25, page_token: "page-1"},
               "token"
             )

    assert revision.revision_id == "rev1"
    assert revision.keep_forever?
  end

  test "gets file revisions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/revisions/rev1"
      assert conn.query_params["acknowledgeAbuse"] == "false"
      assert conn.query_params["fields"] == Fields.revision_metadata()

      Req.Test.json(conn, %{
        "id" => "rev1",
        "mimeType" => "application/pdf",
        "published" => false,
        "keepForever" => true,
        "size" => "4096"
      })
    end)

    assert {:ok, %Revision{} = revision} =
             Client.get_revision(
               %{file_id: "file123", revision_id: "rev1", acknowledge_abuse: false},
               "token"
             )

    assert revision.revision_id == "rev1"
    assert revision.size == 4096
  end

  test "updates file revisions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123/revisions/rev1"
      assert conn.query_params["fields"] == Fields.revision_metadata()

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "keepForever" => true,
               "published" => false
             }

      Req.Test.json(conn, %{
        "id" => "rev1",
        "mimeType" => "application/pdf",
        "published" => false,
        "keepForever" => true
      })
    end)

    assert {:ok, %Revision{} = revision} =
             Client.update_revision(
               %{file_id: "file123", revision_id: "rev1", keep_forever: true, published: false},
               "token"
             )

    assert revision.revision_id == "rev1"
    assert revision.keep_forever?
    refute revision.published?
  end

  test "deletes file revisions" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123/revisions/rev1"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{file_id: "file123", revision_id: "rev1", deleted?: true}} =
             Client.delete_revision(%{file_id: "file123", revision_id: "rev1"}, "token")
  end

  test "lists file comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/comments"
      assert conn.query_params["includeDeleted"] == "false"
      assert conn.query_params["pageSize"] == "25"
      assert conn.query_params["fields"] == Fields.comment_list()

      Req.Test.json(conn, %{
        "comments" => [
          %{"id" => "comment123", "content" => "Looks good", "resolved" => false}
        ],
        "nextPageToken" => "next-comment"
      })
    end)

    assert {:ok, %{comments: [%Comment{} = comment], next_page_token: "next-comment"}} =
             Client.list_comments(
               %{file_id: "file123", include_deleted: false, page_size: 25},
               "token"
             )

    assert comment.comment_id == "comment123"
    assert comment.content == "Looks good"
  end

  test "gets file comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/comments/comment123"
      assert conn.query_params["includeDeleted"] == "false"
      assert conn.query_params["fields"] == Fields.comment_metadata()

      Req.Test.json(conn, %{"id" => "comment123", "content" => "Looks good"})
    end)

    assert {:ok, %Comment{} = comment} =
             Client.get_comment(
               %{file_id: "file123", comment_id: "comment123", include_deleted: false},
               "token"
             )

    assert comment.comment_id == "comment123"
  end

  test "creates file comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/comments"
      assert conn.query_params["fields"] == Fields.comment_metadata()

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "content" => "Looks good",
               "anchor" => "{\"r\":\"head\"}"
             }

      Req.Test.json(conn, %{"id" => "comment456", "content" => "Looks good"})
    end)

    assert {:ok, %Comment{} = comment} =
             Client.create_comment(
               %{file_id: "file123", content: "Looks good", anchor: "{\"r\":\"head\"}"},
               "token"
             )

    assert comment.comment_id == "comment456"
  end

  test "updates file comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123/comments/comment123"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"content" => "Updated"}

      Req.Test.json(conn, %{"id" => "comment123", "content" => "Updated"})
    end)

    assert {:ok, %Comment{} = comment} =
             Client.update_comment(
               %{file_id: "file123", comment_id: "comment123", content: "Updated"},
               "token"
             )

    assert comment.content == "Updated"
  end

  test "deletes file comments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123/comments/comment123"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{file_id: "file123", comment_id: "comment123", deleted?: true}} =
             Client.delete_comment(%{file_id: "file123", comment_id: "comment123"}, "token")
  end

  test "lists comment replies" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/comments/comment123/replies"
      assert conn.query_params["includeDeleted"] == "false"
      assert conn.query_params["pageSize"] == "25"
      assert conn.query_params["fields"] == Fields.reply_list()

      Req.Test.json(conn, %{
        "replies" => [
          %{"id" => "reply123", "content" => "Agreed"}
        ],
        "nextPageToken" => "next-reply"
      })
    end)

    assert {:ok, %{replies: [%Reply{} = reply], next_page_token: "next-reply"}} =
             Client.list_replies(
               %{
                 file_id: "file123",
                 comment_id: "comment123",
                 include_deleted: false,
                 page_size: 25
               },
               "token"
             )

    assert reply.reply_id == "reply123"
  end

  test "gets comment replies" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/file123/comments/comment123/replies/reply123"
      assert conn.query_params["includeDeleted"] == "false"
      assert conn.query_params["fields"] == Fields.reply_metadata()

      Req.Test.json(conn, %{"id" => "reply123", "content" => "Agreed"})
    end)

    assert {:ok, %Reply{} = reply} =
             Client.get_reply(
               %{
                 file_id: "file123",
                 comment_id: "comment123",
                 reply_id: "reply123",
                 include_deleted: false
               },
               "token"
             )

    assert reply.reply_id == "reply123"
  end

  test "creates comment replies" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/comments/comment123/replies"
      assert conn.query_params["fields"] == Fields.reply_metadata()

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"content" => "Agreed"}

      Req.Test.json(conn, %{"id" => "reply456", "content" => "Agreed"})
    end)

    assert {:ok, %Reply{} = reply} =
             Client.create_reply(
               %{file_id: "file123", comment_id: "comment123", content: "Agreed"},
               "token"
             )

    assert reply.reply_id == "reply456"
  end

  test "updates comment replies" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/files/file123/comments/comment123/replies/reply123"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"content" => "Updated"}

      Req.Test.json(conn, %{"id" => "reply123", "content" => "Updated"})
    end)

    assert {:ok, %Reply{} = reply} =
             Client.update_reply(
               %{
                 file_id: "file123",
                 comment_id: "comment123",
                 reply_id: "reply123",
                 content: "Updated"
               },
               "token"
             )

    assert reply.content == "Updated"
  end

  test "deletes comment replies" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/files/file123/comments/comment123/replies/reply123"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok,
            %{file_id: "file123", comment_id: "comment123", reply_id: "reply123", deleted?: true}} =
             Client.delete_reply(
               %{file_id: "file123", comment_id: "comment123", reply_id: "reply123"},
               "token"
             )
  end

  test "lists shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/drives"
      assert conn.query_params["pageSize"] == "25"
      assert conn.query_params["q"] == "name contains 'Team'"
      assert conn.query_params["useDomainAdminAccess"] == "false"
      assert conn.query_params["fields"] == Fields.shared_drive_list()

      Req.Test.json(conn, %{
        "drives" => [%{"id" => "drive123", "name" => "Team Drive"}],
        "nextPageToken" => "next-drive"
      })
    end)

    assert {:ok, %{shared_drives: [%SharedDrive{} = shared_drive], next_page_token: "next-drive"}} =
             Client.list_shared_drives(
               %{page_size: 25, query: "name contains 'Team'", use_domain_admin_access: false},
               "token"
             )

    assert shared_drive.shared_drive_id == "drive123"
  end

  test "gets shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/drives/drive123"
      assert conn.query_params["useDomainAdminAccess"] == "false"
      assert conn.query_params["fields"] == Fields.shared_drive_metadata()

      Req.Test.json(conn, %{"id" => "drive123", "name" => "Team Drive"})
    end)

    assert {:ok, %SharedDrive{} = shared_drive} =
             Client.get_shared_drive(
               %{shared_drive_id: "drive123", use_domain_admin_access: false},
               "token"
             )

    assert shared_drive.name == "Team Drive"
  end

  test "creates shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/drives"
      assert conn.query_params["requestId"] == "request-123"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"name" => "Team Drive"}

      Req.Test.json(conn, %{"id" => "drive123", "name" => "Team Drive"})
    end)

    assert {:ok, %SharedDrive{} = shared_drive} =
             Client.create_shared_drive(
               %{request_id: "request-123", name: "Team Drive"},
               "token"
             )

    assert shared_drive.shared_drive_id == "drive123"
  end

  test "updates shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/drives/drive123"
      assert conn.query_params["useDomainAdminAccess"] == "false"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{"name" => "Team Drive Renamed"}

      Req.Test.json(conn, %{"id" => "drive123", "name" => "Team Drive Renamed"})
    end)

    assert {:ok, %SharedDrive{} = shared_drive} =
             Client.update_shared_drive(
               %{
                 shared_drive_id: "drive123",
                 name: "Team Drive Renamed",
                 use_domain_admin_access: false
               },
               "token"
             )

    assert shared_drive.name == "Team Drive Renamed"
  end

  test "deletes shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/drives/drive123"
      assert conn.query_params["useDomainAdminAccess"] == "false"
      assert conn.query_params["allowItemDeletion"] == "false"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{shared_drive_id: "drive123", deleted?: true}} =
             Client.delete_shared_drive(
               %{
                 shared_drive_id: "drive123",
                 use_domain_admin_access: false,
                 allow_item_deletion: false
               },
               "token"
             )
  end

  test "hides and unhides shared drives" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path in ["/v3/drives/drive123/hide", "/v3/drives/drive123/unhide"]
      assert conn.query_params["fields"] == Fields.shared_drive_metadata()

      hidden? = conn.request_path == "/v3/drives/drive123/hide"
      Req.Test.json(conn, %{"id" => "drive123", "name" => "Team Drive", "hidden" => hidden?})
    end)

    assert {:ok, %SharedDrive{hidden?: true}} =
             Client.hide_shared_drive(%{shared_drive_id: "drive123"}, "token")

    assert {:ok, %SharedDrive{hidden?: false}} =
             Client.unhide_shared_drive(%{shared_drive_id: "drive123"}, "token")
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

  test "starts a changes watch channel" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/changes/watch"
      assert conn.query_params["pageToken"] == "start-token"
      assert conn.query_params["pageSize"] == "100"
      assert conn.query_params["spaces"] == "drive"
      assert conn.query_params["includeRemoved"] == "true"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "channel-123",
               "type" => "web_hook",
               "address" => "https://example.com/drive/webhook",
               "token" => "route=drive",
               "expiration" => 1_770_000_000_000
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "channel-123",
        "resourceId" => "resource-123",
        "resourceUri" => "https://www.googleapis.com/drive/v3/changes",
        "token" => "route=drive",
        "expiration" => 1_770_000_000_000
      })
    end)

    assert {:ok, %Channel{} = channel} =
             Client.watch_changes(
               %{
                 page_token: "start-token",
                 page_size: 100,
                 spaces: "drive",
                 include_removed: true,
                 channel_id: "channel-123",
                 address: "https://example.com/drive/webhook",
                 token: "route=drive",
                 expiration_ms: 1_770_000_000_000
               },
               "token"
             )

    assert channel.channel_id == "channel-123"
    assert channel.resource_id == "resource-123"
    assert channel.expiration == "1770000000000"
  end

  test "starts a file watch channel" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files/file123/watch"
      assert conn.query_params["supportsAllDrives"] == "true"
      assert conn.query_params["includePermissionsForView"] == "published"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "file-channel-123",
               "type" => "web_hook",
               "address" => "https://example.com/drive/file-webhook"
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "file-channel-123",
        "resourceId" => "file-resource-123",
        "resourceUri" => "https://www.googleapis.com/drive/v3/files/file123"
      })
    end)

    assert {:ok, %Channel{} = channel} =
             Client.watch_file(
               %{
                 file_id: "file123",
                 channel_id: "file-channel-123",
                 address: "https://example.com/drive/file-webhook",
                 supports_all_drives: true,
                 include_permissions_for_view: "published"
               },
               "token"
             )

    assert channel.channel_id == "file-channel-123"
    assert channel.resource_uri == "https://www.googleapis.com/drive/v3/files/file123"
  end

  test "stops a watch channel" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/channels/stop"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "channel-123",
               "resourceId" => "resource-123"
             }

      Req.Test.json(conn, %{})
    end)

    assert {:ok, %{channel_id: "channel-123", resource_id: "resource-123", stopped?: true}} =
             Client.stop_channel(
               %{channel_id: "channel-123", resource_id: "resource-123"},
               "token"
             )
  end
end
