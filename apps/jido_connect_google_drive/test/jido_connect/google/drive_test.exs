defmodule Jido.Connect.Google.DriveTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.Google.Drive

  @drive_action_modules [
    Jido.Connect.Google.Drive.Actions.ListFiles,
    Jido.Connect.Google.Drive.Actions.GetFile,
    Jido.Connect.Google.Drive.Actions.CreateFile,
    Jido.Connect.Google.Drive.Actions.CreateFolder,
    Jido.Connect.Google.Drive.Actions.CopyFile,
    Jido.Connect.Google.Drive.Actions.UpdateFile,
    Jido.Connect.Google.Drive.Actions.ExportFile,
    Jido.Connect.Google.Drive.Actions.DownloadFile,
    Jido.Connect.Google.Drive.Actions.DeleteFile,
    Jido.Connect.Google.Drive.Actions.ListPermissions,
    Jido.Connect.Google.Drive.Actions.CreatePermission,
    Jido.Connect.Google.Drive.Actions.GetPermission,
    Jido.Connect.Google.Drive.Actions.UpdatePermission,
    Jido.Connect.Google.Drive.Actions.DeletePermission,
    Jido.Connect.Google.Drive.Actions.ListRevisions,
    Jido.Connect.Google.Drive.Actions.GetRevision,
    Jido.Connect.Google.Drive.Actions.UpdateRevision,
    Jido.Connect.Google.Drive.Actions.DeleteRevision,
    Jido.Connect.Google.Drive.Actions.ListComments,
    Jido.Connect.Google.Drive.Actions.GetComment,
    Jido.Connect.Google.Drive.Actions.CreateComment,
    Jido.Connect.Google.Drive.Actions.UpdateComment,
    Jido.Connect.Google.Drive.Actions.DeleteComment,
    Jido.Connect.Google.Drive.Actions.ListReplies,
    Jido.Connect.Google.Drive.Actions.GetReply,
    Jido.Connect.Google.Drive.Actions.CreateReply,
    Jido.Connect.Google.Drive.Actions.UpdateReply,
    Jido.Connect.Google.Drive.Actions.DeleteReply,
    Jido.Connect.Google.Drive.Actions.ListSharedDrives,
    Jido.Connect.Google.Drive.Actions.GetSharedDrive,
    Jido.Connect.Google.Drive.Actions.CreateSharedDrive,
    Jido.Connect.Google.Drive.Actions.UpdateSharedDrive,
    Jido.Connect.Google.Drive.Actions.DeleteSharedDrive,
    Jido.Connect.Google.Drive.Actions.HideSharedDrive,
    Jido.Connect.Google.Drive.Actions.UnhideSharedDrive,
    Jido.Connect.Google.Drive.Actions.WatchChanges,
    Jido.Connect.Google.Drive.Actions.WatchFile,
    Jido.Connect.Google.Drive.Actions.StopChannel
  ]

  @drive_dsl_fragments [
    Jido.Connect.Google.Drive.Actions.Read,
    Jido.Connect.Google.Drive.Actions.Write,
    Jido.Connect.Google.Drive.Actions.FileContent,
    Jido.Connect.Google.Drive.Actions.Permissions,
    Jido.Connect.Google.Drive.Actions.Revisions,
    Jido.Connect.Google.Drive.Actions.Comments,
    Jido.Connect.Google.Drive.Actions.Replies,
    Jido.Connect.Google.Drive.Actions.SharedDrives,
    Jido.Connect.Google.Drive.Actions.Watch,
    Jido.Connect.Google.Drive.Triggers.Changes
  ]

  defmodule FakeDriveClient do
    def list_files(
          %{
            query: "mimeType = 'application/pdf'",
            page_size: 25,
            spaces: "drive",
            include_items_from_all_drives: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         files: [
           Drive.File.new!(%{
             file_id: "file123",
             name: "Budget.pdf",
             mime_type: "application/pdf",
             parents: ["folder123"]
           })
         ],
         next_page_token: "next"
       }}
    end

    def get_file(
          %{file_id: "file123", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "file123",
         name: "Budget.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def create_file(
          %{
            name: "Notes",
            mime_type: "text/plain",
            parents: ["folder123"],
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "created123",
         name: "Notes",
         mime_type: "text/plain",
         parents: ["folder123"]
       })}
    end

    def create_folder(
          %{name: "Reports", parents: ["root"], supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.Folder.new!(%{
         folder_id: "folder456",
         name: "Reports",
         parents: ["root"]
       })}
    end

    def copy_file(
          %{
            file_id: "file123",
            name: "Budget Copy.pdf",
            parents: ["folder123"],
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "copy123",
         name: "Budget Copy.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def update_file(
          %{file_id: "file123", name: "Renamed.pdf", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "file123",
         name: "Renamed.pdf",
         mime_type: "application/pdf",
         parents: ["folder123"]
       })}
    end

    def export_file(
          %{file_id: "file123", mime_type: "text/csv", supports_all_drives: false},
          "token"
        ) do
      {:ok,
       %{
         file_id: "file123",
         mime_type: "text/csv",
         content: "name,total\nBudget,10\n",
         encoding: "utf-8",
         binary: false,
         size: 21
       }}
    end

    def download_file(%{file_id: "file123", supports_all_drives: false}, "token") do
      {:ok,
       %{
         file_id: "file123",
         mime_type: "application/pdf",
         content_base64: "AAEC",
         encoding: "base64",
         binary: true,
         size: 3
       }}
    end

    def delete_file(%{file_id: "file123", supports_all_drives: false}, "token") do
      {:ok, %{file_id: "file123", deleted?: true}}
    end

    def list_permissions(
          %{
            file_id: "file123",
            page_size: 100,
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       %{
         permissions: [
           Drive.Permission.new!(%{
             permission_id: "perm123",
             type: "user",
             role: "reader",
             email_address: "reader@example.com"
           })
         ],
         next_page_token: "next-perm"
       }}
    end

    def create_permission(
          %{
            file_id: "file123",
            type: "user",
            role: "reader",
            email_address: "reader@example.com",
            transfer_ownership: false,
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       Drive.Permission.new!(%{
         permission_id: "perm456",
         type: "user",
         role: "reader",
         email_address: "reader@example.com"
       })}
    end

    def get_permission(
          %{
            file_id: "file123",
            permission_id: "perm123",
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       Drive.Permission.new!(%{
         permission_id: "perm123",
         type: "user",
         role: "reader",
         email_address: "reader@example.com"
       })}
    end

    def update_permission(
          %{
            file_id: "file123",
            permission_id: "perm123",
            role: "writer",
            transfer_ownership: false,
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       Drive.Permission.new!(%{
         permission_id: "perm123",
         type: "user",
         role: "writer",
         email_address: "reader@example.com"
       })}
    end

    def delete_permission(
          %{
            file_id: "file123",
            permission_id: "perm123",
            supports_all_drives: false,
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok, %{file_id: "file123", permission_id: "perm123", deleted?: true}}
    end

    def list_revisions(%{file_id: "file123", page_size: 100}, "token") do
      {:ok,
       %{
         revisions: [
           Drive.Revision.new!(%{
             revision_id: "rev1",
             mime_type: "application/pdf",
             keep_forever?: false,
             modified_time: "2026-05-05T12:00:00Z"
           })
         ],
         next_page_token: "next-rev"
       }}
    end

    def get_revision(
          %{file_id: "file123", revision_id: "rev1", acknowledge_abuse: false},
          "token"
        ) do
      {:ok,
       Drive.Revision.new!(%{
         revision_id: "rev1",
         mime_type: "application/pdf",
         keep_forever?: false,
         modified_time: "2026-05-05T12:00:00Z"
       })}
    end

    def update_revision(
          %{file_id: "file123", revision_id: "rev1", keep_forever: true},
          "token"
        ) do
      {:ok,
       Drive.Revision.new!(%{
         revision_id: "rev1",
         mime_type: "application/pdf",
         keep_forever?: true,
         modified_time: "2026-05-05T12:00:00Z"
       })}
    end

    def delete_revision(%{file_id: "file123", revision_id: "rev1"}, "token") do
      {:ok, %{file_id: "file123", revision_id: "rev1", deleted?: true}}
    end

    def list_comments(
          %{file_id: "file123", include_deleted: false, page_size: 100},
          "token"
        ) do
      {:ok,
       %{
         comments: [
           Drive.Comment.new!(%{
             comment_id: "comment123",
             content: "Looks good",
             resolved?: false
           })
         ],
         next_page_token: "next-comment"
       }}
    end

    def get_comment(
          %{file_id: "file123", comment_id: "comment123", include_deleted: false},
          "token"
        ) do
      {:ok,
       Drive.Comment.new!(%{
         comment_id: "comment123",
         content: "Looks good",
         resolved?: false
       })}
    end

    def create_comment(%{file_id: "file123", content: "Looks good"}, "token") do
      {:ok,
       Drive.Comment.new!(%{
         comment_id: "comment456",
         content: "Looks good",
         resolved?: false
       })}
    end

    def update_comment(
          %{file_id: "file123", comment_id: "comment123", content: "Updated"},
          "token"
        ) do
      {:ok,
       Drive.Comment.new!(%{
         comment_id: "comment123",
         content: "Updated",
         resolved?: false
       })}
    end

    def delete_comment(%{file_id: "file123", comment_id: "comment123"}, "token") do
      {:ok, %{file_id: "file123", comment_id: "comment123", deleted?: true}}
    end

    def list_replies(
          %{file_id: "file123", comment_id: "comment123", include_deleted: false, page_size: 100},
          "token"
        ) do
      {:ok,
       %{
         replies: [
           Drive.Reply.new!(%{
             reply_id: "reply123",
             content: "Agreed"
           })
         ],
         next_page_token: "next-reply"
       }}
    end

    def get_reply(
          %{
            file_id: "file123",
            comment_id: "comment123",
            reply_id: "reply123",
            include_deleted: false
          },
          "token"
        ) do
      {:ok,
       Drive.Reply.new!(%{
         reply_id: "reply123",
         content: "Agreed"
       })}
    end

    def create_reply(%{file_id: "file123", comment_id: "comment123", content: "Agreed"}, "token") do
      {:ok,
       Drive.Reply.new!(%{
         reply_id: "reply456",
         content: "Agreed"
       })}
    end

    def update_reply(
          %{
            file_id: "file123",
            comment_id: "comment123",
            reply_id: "reply123",
            content: "Updated"
          },
          "token"
        ) do
      {:ok,
       Drive.Reply.new!(%{
         reply_id: "reply123",
         content: "Updated"
       })}
    end

    def delete_reply(
          %{file_id: "file123", comment_id: "comment123", reply_id: "reply123"},
          "token"
        ) do
      {:ok, %{file_id: "file123", comment_id: "comment123", reply_id: "reply123", deleted?: true}}
    end

    def list_shared_drives(%{page_size: 100, use_domain_admin_access: false}, "token") do
      {:ok,
       %{
         shared_drives: [
           Drive.SharedDrive.new!(%{
             shared_drive_id: "drive123",
             name: "Team Drive"
           })
         ],
         next_page_token: "next-drive"
       }}
    end

    def get_shared_drive(%{shared_drive_id: "drive123", use_domain_admin_access: false}, "token") do
      {:ok,
       Drive.SharedDrive.new!(%{
         shared_drive_id: "drive123",
         name: "Team Drive"
       })}
    end

    def create_shared_drive(%{request_id: "request-123", name: "Team Drive"}, "token") do
      {:ok,
       Drive.SharedDrive.new!(%{
         shared_drive_id: "drive123",
         name: "Team Drive"
       })}
    end

    def update_shared_drive(
          %{
            shared_drive_id: "drive123",
            name: "Team Drive Renamed",
            use_domain_admin_access: false
          },
          "token"
        ) do
      {:ok,
       Drive.SharedDrive.new!(%{
         shared_drive_id: "drive123",
         name: "Team Drive Renamed"
       })}
    end

    def delete_shared_drive(
          %{
            shared_drive_id: "drive123",
            use_domain_admin_access: false,
            allow_item_deletion: false
          },
          "token"
        ) do
      {:ok, %{shared_drive_id: "drive123", deleted?: true}}
    end

    def hide_shared_drive(%{shared_drive_id: "drive123"}, "token") do
      {:ok,
       Drive.SharedDrive.new!(%{
         shared_drive_id: "drive123",
         name: "Team Drive",
         hidden?: true
       })}
    end

    def unhide_shared_drive(%{shared_drive_id: "drive123"}, "token") do
      {:ok,
       Drive.SharedDrive.new!(%{
         shared_drive_id: "drive123",
         name: "Team Drive",
         hidden?: false
       })}
    end

    def watch_changes(
          %{
            page_token: "start-token",
            channel_id: "channel-123",
            address: "https://example.com/drive/webhook",
            channel_type: "web_hook",
            token: "route=drive",
            expiration_ms: 1_770_000_000_000,
            page_size: 100,
            spaces: "drive",
            include_corpus_removals: false,
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.Channel.new!(%{
         channel_id: "channel-123",
         resource_id: "resource-123",
         resource_uri: "https://www.googleapis.com/drive/v3/changes",
         token: "route=drive",
         expiration: "1770000000000",
         kind: "api#channel"
       })}
    end

    def watch_file(
          %{
            file_id: "file123",
            channel_id: "file-channel-123",
            address: "https://example.com/drive/file-webhook",
            channel_type: "web_hook",
            acknowledge_abuse: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.Channel.new!(%{
         channel_id: "file-channel-123",
         resource_id: "file-resource-123",
         resource_uri: "https://www.googleapis.com/drive/v3/files/file123",
         kind: "api#channel"
       })}
    end

    def stop_channel(
          %{channel_id: "channel-123", resource_id: "resource-123"},
          "token"
        ) do
      {:ok, %{channel_id: "channel-123", resource_id: "resource-123", stopped?: true}}
    end

    def get_start_page_token(%{supports_all_drives: false}, "token") do
      {:ok, %{start_page_token: "start-token"}}
    end

    def list_changes(
          %{
            page_token: "start-token",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         changes: [
           Drive.Change.new!(%{
             change_id: "change123",
             file_id: "file123",
             removed?: false,
             time: "2026-05-05T12:00:00Z",
             change_type: "file",
             file:
               Drive.File.new!(%{
                 file_id: "file123",
                 name: "Budget.pdf",
                 mime_type: "application/pdf"
               })
           })
         ],
         new_start_page_token: "next-token"
       }}
    end

    def list_changes(
          %{
            page_token: "paged-start",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         changes: [
           Drive.Change.new!(%{
             change_id: "change123",
             file_id: "file123",
             removed?: false,
             time: "2026-05-05T12:00:00Z",
             change_type: "file",
             file:
               Drive.File.new!(%{
                 file_id: "file123",
                 name: "Budget.pdf",
                 mime_type: "application/pdf"
               })
           })
         ],
         next_page_token: "page-2"
       }}
    end

    def list_changes(
          %{
            page_token: "page-2",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       %{
         changes: [
           Drive.Change.new!(%{
             change_id: "change123",
             file_id: "file123",
             removed?: false,
             time: "2026-05-05T12:00:00Z",
             change_type: "file",
             file:
               Drive.File.new!(%{
                 file_id: "file123",
                 name: "Budget duplicate.pdf",
                 mime_type: "application/pdf"
               })
           }),
           Drive.Change.new!(%{
             change_id: "change456",
             file_id: "file456",
             removed?: false,
             time: "2026-05-05T12:05:00Z",
             change_type: "file",
             file:
               Drive.File.new!(%{
                 file_id: "file456",
                 name: "Forecast.pdf",
                 mime_type: "application/pdf"
               })
           })
         ],
         new_start_page_token: "paged-next-token"
       }}
    end

    def list_changes(
          %{
            page_token: "expired-token",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:error,
       Connect.Error.provider("Google API request failed",
         provider: :google,
         reason: :http_error,
         status: 410,
         details: %{message: "Start page token is no longer valid"}
       )}
    end

    def list_changes(
          %{
            page_token: "loop-token",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok, %{changes: [], next_page_token: "loop-page"}}
    end

    def list_changes(
          %{
            page_token: "loop-page",
            page_size: 100,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok, %{changes: [], next_page_token: "loop-page"}}
    end
  end

  test "declares Google Drive provider metadata" do
    spec = Drive.integration()

    assert spec.id == :google_drive
    assert spec.package == :jido_connect_google_drive
    assert spec.name == "Google Drive"
    assert spec.tags == [:google, :workspace, :files, :productivity]

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Drive,
      id_prefix: "google.drive.",
      pack_id_prefix: "google_drive_",
      module_namespace: Jido.Connect.Google.Drive
    )

    auth_profiles = Map.new(spec.auth_profiles, &{&1.id, &1})

    assert %{user: %{kind: :oauth2}, service_account: %{kind: :service_account}} =
             auth_profiles

    assert %{
             id: :user,
             kind: :oauth2,
             refresh?: true,
             pkce?: true
           } = profile = auth_profiles.user

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/drive.metadata.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.file" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.readonly" in profile.optional_scopes

    assert auth_profiles.service_account.setup == :google_service_account_jwt

    assert auth_profiles.service_account.credential_fields == [
             :client_email,
             :private_key,
             :private_key_id
           ]

    assert auth_profiles.domain_delegated_service_account.setup == :google_domain_wide_delegation

    assert auth_profiles.domain_delegated_service_account.credential_fields == [
             :client_email,
             :private_key,
             :private_key_id,
             :subject
           ]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.drive.files.list",
             "google.drive.file.get",
             "google.drive.file.create",
             "google.drive.folder.create",
             "google.drive.file.copy",
             "google.drive.file.update",
             "google.drive.file.export",
             "google.drive.file.download",
             "google.drive.file.delete",
             "google.drive.permissions.list",
             "google.drive.permission.create",
             "google.drive.permission.get",
             "google.drive.permission.update",
             "google.drive.permission.delete",
             "google.drive.revisions.list",
             "google.drive.revision.get",
             "google.drive.revision.update",
             "google.drive.revision.delete",
             "google.drive.comments.list",
             "google.drive.comment.get",
             "google.drive.comment.create",
             "google.drive.comment.update",
             "google.drive.comment.delete",
             "google.drive.replies.list",
             "google.drive.reply.get",
             "google.drive.reply.create",
             "google.drive.reply.update",
             "google.drive.reply.delete",
             "google.drive.shared_drives.list",
             "google.drive.shared_drive.get",
             "google.drive.shared_drive.create",
             "google.drive.shared_drive.update",
             "google.drive.shared_drive.delete",
             "google.drive.shared_drive.hide",
             "google.drive.shared_drive.unhide",
             "google.drive.changes.watch",
             "google.drive.file.watch",
             "google.drive.channel.stop"
           ]

    list_files = Enum.find(spec.actions, &(&1.id == "google.drive.files.list"))
    get_file = Enum.find(spec.actions, &(&1.id == "google.drive.file.get"))
    list_permissions = Enum.find(spec.actions, &(&1.id == "google.drive.permissions.list"))

    list_files_fields = Enum.find(list_files.input, &(&1.name == :fields))
    get_file_fields = Enum.find(get_file.input, &(&1.name == :fields))
    permission_fields = Enum.find(list_permissions.input, &(&1.name == :fields))

    list_files_permission_view =
      Enum.find(list_files.input, &(&1.name == :include_permissions_for_view))

    get_file_permission_view =
      Enum.find(get_file.input, &(&1.name == :include_permissions_for_view))

    assert list_files_fields.metadata.presets.with_permissions ==
             Jido.Connect.Google.Drive.Fields.file_list_with_permissions()

    assert get_file_fields.metadata.presets.with_permissions ==
             Jido.Connect.Google.Drive.Fields.file_with_permissions()

    assert permission_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.permission_list()

    assert list_files_permission_view.enum == ["published"]
    assert get_file_permission_view.enum == ["published"]

    delete_action = Enum.find(spec.actions, &(&1.id == "google.drive.file.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always

    create_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.create"))
    get_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.get"))
    update_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.update"))
    delete_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.delete"))
    list_revisions = Enum.find(spec.actions, &(&1.id == "google.drive.revisions.list"))
    get_revision = Enum.find(spec.actions, &(&1.id == "google.drive.revision.get"))
    update_revision = Enum.find(spec.actions, &(&1.id == "google.drive.revision.update"))
    delete_revision = Enum.find(spec.actions, &(&1.id == "google.drive.revision.delete"))
    list_comments = Enum.find(spec.actions, &(&1.id == "google.drive.comments.list"))
    create_comment = Enum.find(spec.actions, &(&1.id == "google.drive.comment.create"))
    update_comment = Enum.find(spec.actions, &(&1.id == "google.drive.comment.update"))
    delete_comment = Enum.find(spec.actions, &(&1.id == "google.drive.comment.delete"))
    list_replies = Enum.find(spec.actions, &(&1.id == "google.drive.replies.list"))
    create_reply = Enum.find(spec.actions, &(&1.id == "google.drive.reply.create"))
    update_reply = Enum.find(spec.actions, &(&1.id == "google.drive.reply.update"))
    delete_reply = Enum.find(spec.actions, &(&1.id == "google.drive.reply.delete"))
    list_shared_drives = Enum.find(spec.actions, &(&1.id == "google.drive.shared_drives.list"))
    create_shared_drive = Enum.find(spec.actions, &(&1.id == "google.drive.shared_drive.create"))
    update_shared_drive = Enum.find(spec.actions, &(&1.id == "google.drive.shared_drive.update"))
    delete_shared_drive = Enum.find(spec.actions, &(&1.id == "google.drive.shared_drive.delete"))
    hide_shared_drive = Enum.find(spec.actions, &(&1.id == "google.drive.shared_drive.hide"))
    assert create_permission.risk == :external_write
    assert create_permission.confirmation == :always
    assert get_permission.risk == :read
    assert update_permission.risk == :external_write
    assert update_permission.confirmation == :always
    assert delete_permission.risk == :destructive
    assert delete_permission.confirmation == :always
    assert list_revisions.risk == :read
    assert get_revision.risk == :read
    assert update_revision.risk == :write
    assert update_revision.confirmation == :required_for_ai
    assert delete_revision.risk == :destructive
    assert delete_revision.confirmation == :always
    assert list_comments.risk == :read
    assert create_comment.risk == :external_write
    assert create_comment.confirmation == :always
    assert update_comment.risk == :write
    assert update_comment.confirmation == :required_for_ai
    assert delete_comment.risk == :destructive
    assert delete_comment.confirmation == :always
    assert list_replies.risk == :read
    assert create_reply.risk == :external_write
    assert create_reply.confirmation == :always
    assert update_reply.risk == :write
    assert update_reply.confirmation == :required_for_ai
    assert delete_reply.risk == :destructive
    assert delete_reply.confirmation == :always
    assert list_shared_drives.risk == :read
    assert create_shared_drive.risk == :write
    assert create_shared_drive.confirmation == :required_for_ai
    assert update_shared_drive.risk == :write
    assert update_shared_drive.confirmation == :required_for_ai
    assert delete_shared_drive.risk == :destructive
    assert delete_shared_drive.confirmation == :always
    assert hide_shared_drive.risk == :write
    assert hide_shared_drive.confirmation == :required_for_ai

    watch_changes = Enum.find(spec.actions, &(&1.id == "google.drive.changes.watch"))
    watch_file = Enum.find(spec.actions, &(&1.id == "google.drive.file.watch"))
    stop_channel = Enum.find(spec.actions, &(&1.id == "google.drive.channel.stop"))

    assert watch_changes.risk == :write
    assert watch_file.risk == :write
    assert stop_channel.risk == :write
    assert watch_changes.confirmation == :required_for_ai
    assert watch_file.confirmation == :required_for_ai
    assert stop_channel.confirmation == :required_for_ai

    create_permission_fields = Enum.find(create_permission.input, &(&1.name == :fields))
    get_permission_fields = Enum.find(get_permission.input, &(&1.name == :fields))
    list_revisions_fields = Enum.find(list_revisions.input, &(&1.name == :fields))
    get_revision_fields = Enum.find(get_revision.input, &(&1.name == :fields))
    list_comments_fields = Enum.find(list_comments.input, &(&1.name == :fields))
    create_comment_fields = Enum.find(create_comment.input, &(&1.name == :fields))
    list_replies_fields = Enum.find(list_replies.input, &(&1.name == :fields))
    create_reply_fields = Enum.find(create_reply.input, &(&1.name == :fields))
    list_shared_drives_fields = Enum.find(list_shared_drives.input, &(&1.name == :fields))
    create_shared_drive_fields = Enum.find(create_shared_drive.input, &(&1.name == :fields))

    assert create_permission_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.permission_metadata()

    assert get_permission_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.permission_metadata()

    assert list_revisions_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.revision_list()

    assert get_revision_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.revision_metadata()

    assert list_comments_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.comment_list()

    assert create_comment_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.comment_metadata()

    assert list_replies_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.reply_list()

    assert create_reply_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.reply_metadata()

    assert list_shared_drives_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.shared_drive_list()

    assert create_shared_drive_fields.metadata.presets.default ==
             Jido.Connect.Google.Drive.Fields.shared_drive_metadata()

    for operation <- spec.actions ++ spec.triggers do
      assert operation.auth_profile == :user

      assert operation.auth_profiles == [
               :user,
               :service_account,
               :domain_delegated_service_account
             ]
    end

    assert Enum.find(create_permission.input, &(&1.name == :type)).enum == [
             "user",
             "group",
             "domain",
             "anyone"
           ]

    assert {:ok,
            %{
              id: "google.drive.file.changed",
              kind: :poll,
              checkpoint: :page_token,
              dedupe: %{key: [:change_id, :file_id]},
              scope_resolver: Jido.Connect.Google.Drive.ScopeResolver
            }} =
             Connect.trigger(spec, "google.drive.file.changed")

    assert {:ok,
            %{
              id: "google.drive.file.changed.push",
              kind: :webhook,
              dedupe: %{key: [:channel_id, :resource_id, :message_number]},
              verification: %{
                kind: :google_drive_channel,
                token: :host_verified,
                headers: :x_goog_channel
              },
              scope_resolver: Jido.Connect.Google.Drive.ScopeResolver
            }} =
             Connect.trigger(spec, "google.drive.file.changed.push")
  end

  test "compiles generated Jido modules for actions, sensors, and plugin" do
    ConnectorContracts.assert_generated_surface(Drive,
      otp_app: :jido_connect_google_drive,
      action_modules: @drive_action_modules,
      sensor_specs: [
        %{
          module: Jido.Connect.Google.Drive.Sensors.FileChanged,
          name: "google_drive_file_changed",
          trigger_id: "google.drive.file.changed",
          signal_type: "google.drive.file.changed"
        },
        %{
          module: Jido.Connect.Google.Drive.Sensors.FileChangedPush,
          name: "google_drive_file_changed_push",
          trigger_id: "google.drive.file.changed.push",
          signal_type: "google.drive.file.changed.push"
        }
      ],
      plugin_module: Jido.Connect.Google.Drive.Plugin,
      plugin_name: "google_drive"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Drive,
      readonly_pack: :google_drive_readonly,
      file_writer_pack: :google_drive_file_writer,
      watch_pack: :google_drive_watch
    )
  end

  test "loads Drive Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@drive_dsl_fragments)
  end

  test "resolves Drive scopes for broad grants and operation shapes" do
    resolver = Jido.Connect.Google.Drive.ScopeResolver

    ConnectorContracts.assert_scope_resolver_shape(resolver, [
      "https://www.googleapis.com/auth/drive.metadata.readonly"
    ])

    assert resolver.required_scopes(
             %{id: "google.drive.file.update"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/drive.readonly"]}
           ) == ["https://www.googleapis.com/auth/drive.file"]

    assert resolver.required_scopes(
             %{action_id: "google.drive.file.export"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/drive.file"]}
           ) == ["https://www.googleapis.com/auth/drive.file"]

    assert resolver.required_scopes(
             %{id: "google.drive.file.export"},
             %{},
             %{scopes: []}
           ) == ["https://www.googleapis.com/auth/drive.readonly"]

    assert resolver.required_scopes(
             %{id: "google.drive.comments.list"},
             %{},
             %{scopes: []}
           ) == ["https://www.googleapis.com/auth/drive.readonly"]

    assert resolver.required_scopes(
             %{id: "google.drive.shared_drive.create"},
             %{},
             %{scopes: []}
           ) == ["https://www.googleapis.com/auth/drive"]

    assert resolver.required_scopes(
             %{id: "google.drive.changes.watch"},
             %{},
             %{scopes: ["https://www.googleapis.com/auth/drive.file"]}
           ) == ["https://www.googleapis.com/auth/drive.file"]

    assert resolver.required_scopes(%{}, %{}, %{}) == [
             "https://www.googleapis.com/auth/drive.metadata.readonly"
           ]
  end

  test "invokes list files through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              files: [
                %{
                  file_id: "file123",
                  name: "Budget.pdf",
                  mime_type: "application/pdf",
                  parents: ["folder123"]
                }
              ],
              next_page_token: "next"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.files.list",
               %{query: "mimeType = 'application/pdf'"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes Drive actions with service-account leases" do
    {context, lease} =
      context_and_lease(
        profile: :service_account,
        owner_type: :system,
        owner_id: "svc@example.iam.gserviceaccount.com",
        scopes: ["https://www.googleapis.com/auth/drive.metadata.readonly"]
      )

    assert {:ok, %{files: [%{file_id: "file123", name: "Budget.pdf"}]}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.files.list",
               %{query: "mimeType = 'application/pdf'"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get file through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              file: %{
                file_id: "file123",
                name: "Budget.pdf",
                mime_type: "application/pdf"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "metadata read actions accept broader Drive readonly scope" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok, %{file: %{file_id: "file123"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Drive scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.metadata.readonly"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.get",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "created123", name: "Notes", parents: ["folder123"]}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.create",
               %{name: "Notes", mime_type: "text/plain", parents: ["folder123"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create folder through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{folder: %{folder_id: "folder456", name: "Reports", parents: ["root"]}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.folder.create",
               %{name: "Reports", parents: ["root"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes copy file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "copy123", name: "Budget Copy.pdf"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.copy",
               %{file_id: "file123", name: "Budget Copy.pdf", parents: ["folder123"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{file: %{file_id: "file123", name: "Renamed.pdf"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.update",
               %{file_id: "file123", name: "Renamed.pdf"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes export file through injected client and lease" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok,
            %{
              file_content: %{
                file_id: "file123",
                mime_type: "text/csv",
                content: "name,total\nBudget,10\n",
                encoding: "utf-8",
                binary: false
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.export",
               %{file_id: "file123", mime_type: "text/csv"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes download file through injected client and lease" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.readonly"
        ]
      )

    assert {:ok,
            %{
              file_content: %{
                file_id: "file123",
                mime_type: "application/pdf",
                content_base64: "AAEC",
                encoding: "base64",
                binary: true
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.download",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete file through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{file_id: "file123", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.delete",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "content actions require file content scopes" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.readonly"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.export",
               %{file_id: "file123", mime_type: "text/csv"},
               context: context,
               credential_lease: lease
             )
  end

  test "write actions require drive.file scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["https://www.googleapis.com/auth/drive.file"]
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.update",
               %{file_id: "file123", name: "Renamed.pdf"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list permissions through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              permissions: [
                %{
                  permission_id: "perm123",
                  type: "user",
                  role: "reader",
                  email_address: "reader@example.com"
                }
              ],
              next_page_token: "next-perm"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permissions.list",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create permission through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              permission: %{
                permission_id: "perm456",
                type: "user",
                role: "reader",
                email_address: "reader@example.com"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.create",
               %{
                 file_id: "file123",
                 type: "user",
                 role: "reader",
                 email_address: " reader@example.com "
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get permission through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              permission: %{
                permission_id: "perm123",
                type: "user",
                role: "reader",
                email_address: "reader@example.com"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.get",
               %{file_id: "file123", permission_id: "perm123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update permission through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              permission: %{
                permission_id: "perm123",
                role: "writer",
                email_address: "reader@example.com"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.update",
               %{file_id: "file123", permission_id: "perm123", role: "writer"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete permission through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{file_id: "file123", permission_id: "perm123", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.delete",
               %{file_id: "file123", permission_id: "perm123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes revision actions through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              revisions: [
                %{
                  revision_id: "rev1",
                  mime_type: "application/pdf",
                  keep_forever?: false
                }
              ],
              next_page_token: "next-rev"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revisions.list",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{
              revision: %{
                revision_id: "rev1",
                mime_type: "application/pdf",
                keep_forever?: false
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revision.get",
               %{file_id: "file123", revision_id: "rev1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes revision mutations through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              revision: %{
                revision_id: "rev1",
                mime_type: "application/pdf",
                keep_forever?: true
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revision.update",
               %{file_id: "file123", revision_id: "rev1", keep_forever: true},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{file_id: "file123", revision_id: "rev1", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revision.delete",
               %{file_id: "file123", revision_id: "rev1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes comment read actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: read_content_scopes())

    assert {:ok,
            %{
              comments: [%{comment_id: "comment123", content: "Looks good"}],
              next_page_token: "next-comment"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comments.list",
               %{file_id: "file123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{comment: %{comment_id: "comment123", content: "Looks good"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.get",
               %{file_id: "file123", comment_id: "comment123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes comment mutations through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{comment: %{comment_id: "comment456", content: "Looks good"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.create",
               %{file_id: "file123", content: " Looks good "},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{comment: %{comment_id: "comment123", content: "Updated"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.update",
               %{file_id: "file123", comment_id: "comment123", content: " Updated "},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{file_id: "file123", comment_id: "comment123", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.delete",
               %{file_id: "file123", comment_id: "comment123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes reply read actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: read_content_scopes())

    assert {:ok,
            %{
              replies: [%{reply_id: "reply123", content: "Agreed"}],
              next_page_token: "next-reply"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.replies.list",
               %{file_id: "file123", comment_id: "comment123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{reply: %{reply_id: "reply123", content: "Agreed"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.get",
               %{file_id: "file123", comment_id: "comment123", reply_id: "reply123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes reply mutations through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{reply: %{reply_id: "reply456", content: "Agreed"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.create",
               %{file_id: "file123", comment_id: "comment123", content: " Agreed "},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{reply: %{reply_id: "reply123", content: "Updated"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.update",
               %{
                 file_id: "file123",
                 comment_id: "comment123",
                 reply_id: "reply123",
                 content: " Updated "
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{
              result: %{
                file_id: "file123",
                comment_id: "comment123",
                reply_id: "reply123",
                deleted?: true
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.delete",
               %{file_id: "file123", comment_id: "comment123", reply_id: "reply123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes shared-drive read actions through injected client and lease" do
    {context, lease} = context_and_lease(scopes: read_content_scopes())

    assert {:ok,
            %{
              shared_drives: [%{shared_drive_id: "drive123", name: "Team Drive"}],
              next_page_token: "next-drive"
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drives.list",
               %{},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{shared_drive: %{shared_drive_id: "drive123", name: "Team Drive"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.get",
               %{shared_drive_id: "drive123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes shared-drive admin mutations through injected client and lease" do
    {context, lease} = context_and_lease(scopes: full_drive_scopes())

    assert {:ok, %{shared_drive: %{shared_drive_id: "drive123", name: "Team Drive"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.create",
               %{request_id: " request-123 ", name: " Team Drive "},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{shared_drive: %{shared_drive_id: "drive123", name: "Team Drive Renamed"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.update",
               %{shared_drive_id: "drive123", name: " Team Drive Renamed "},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{shared_drive: %{shared_drive_id: "drive123", hidden?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.hide",
               %{shared_drive_id: "drive123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{shared_drive: %{shared_drive_id: "drive123", hidden?: false}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.unhide",
               %{shared_drive_id: "drive123"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{shared_drive_id: "drive123", deleted?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.delete",
               %{shared_drive_id: "drive123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes changes watch through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{
                channel_id: "channel-123",
                resource_id: "resource-123",
                resource_uri: "https://www.googleapis.com/drive/v3/changes",
                token: "route=drive",
                expiration: "1770000000000"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.changes.watch",
               %{
                 page_token: "start-token",
                 channel_id: " channel-123 ",
                 address: " https://example.com/drive/webhook ",
                 token: "route=drive",
                 expiration_ms: 1_770_000_000_000
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes file watch through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{
                channel_id: "file-channel-123",
                resource_id: "file-resource-123",
                resource_uri: "https://www.googleapis.com/drive/v3/files/file123"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.watch",
               %{
                 file_id: "file123",
                 channel_id: "file-channel-123",
                 address: "https://example.com/drive/file-webhook"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes channel stop through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              result: %{
                channel_id: "channel-123",
                resource_id: "resource-123",
                stopped?: true
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.channel.stop",
               %{channel_id: "channel-123", resource_id: "resource-123"},
               context: context,
               credential_lease: lease
             )
  end

  test "watch actions validate Google channel requirements before client calls" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_drive_channel,
              details: %{field: :address}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.changes.watch",
               %{
                 page_token: "start-token",
                 channel_id: "channel-123",
                 address: "http://example.com/drive/webhook"
               },
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_drive_channel,
              details: %{field: :channel_id, max_length: 64}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.watch",
               %{
                 file_id: "file123",
                 channel_id: String.duplicate("a", 65),
                 address: "https://example.com/drive/webhook"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "create permission validates role and target input" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_permission,
              details: %{field: :email_address}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.create",
               %{file_id: "file123", type: "user", role: "reader"},
               context: context,
               credential_lease: lease
             )
  end

  test "create permission rejects whitespace-only targets" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_permission,
              details: %{field: :email_address}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.create",
               %{file_id: "file123", type: "user", role: "reader", email_address: "  "},
               context: context,
               credential_lease: lease
             )
  end

  test "permission update validates mutation inputs" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_permission,
              details: %{field: :permission_update}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.update",
               %{file_id: "file123", permission_id: "perm123"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_permission,
              details: %{field: :transfer_ownership}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.permission.update",
               %{file_id: "file123", permission_id: "perm123", role: "owner"},
               context: context,
               credential_lease: lease
             )
  end

  test "revision update validates mutation inputs" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_revision,
              details: %{field: :revision_update}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revision.update",
               %{file_id: "file123", revision_id: "rev1"},
               context: context,
               credential_lease: lease
             )
  end

  test "comment mutations validate content inputs" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_comment,
              details: %{field: :content}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.create",
               %{file_id: "file123", content: "  "},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_comment,
              details: %{field: :content}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.comment.update",
               %{file_id: "file123", comment_id: "comment123", content: "  "},
               context: context,
               credential_lease: lease
             )
  end

  test "reply mutations validate payload inputs" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_reply,
              details: %{field: :reply_create}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.create",
               %{file_id: "file123", comment_id: "comment123"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_reply,
              details: %{field: :content}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.reply.update",
               %{
                 file_id: "file123",
                 comment_id: "comment123",
                 reply_id: "reply123",
                 content: "  "
               },
               context: context,
               credential_lease: lease
             )
  end

  test "shared-drive mutations validate admin inputs" do
    {context, lease} = context_and_lease(scopes: full_drive_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_shared_drive,
              details: %{field: :name}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.create",
               %{request_id: "request-123", name: "  "},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_shared_drive,
              details: %{field: :shared_drive_update}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.update",
               %{shared_drive_id: "drive123"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_shared_drive,
              details: %{field: :allow_item_deletion}
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.shared_drive.delete",
               %{shared_drive_id: "drive123", allow_item_deletion: true},
               context: context,
               credential_lease: lease
             )
  end

  test "file change poll initializes checkpoint without replaying history" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "start-token"}} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "file change poll emits normalized changes and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  change_id: "change123",
                  file_id: "file123",
                  removed: false,
                  time: "2026-05-05T12:00:00Z",
                  change_type: "file",
                  file: %{file_id: "file123", name: "Budget.pdf"}
                }
              ],
              checkpoint: "next-token"
            }} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "start-token"
             )
  end

  test "file change poll drains pages, dedupes changes, and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  change_id: "change123",
                  file_id: "file123",
                  file: %{name: "Budget.pdf"}
                },
                %{
                  change_id: "change456",
                  file_id: "file456",
                  file: %{name: "Forecast.pdf"}
                }
              ],
              checkpoint: "paged-next-token"
            }} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "paged-start"
             )
  end

  test "file change poll surfaces expired change tokens as checkpoint errors" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 410,
              details: %{
                checkpoint: "expired-token",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "expired-token"
             )
  end

  test "file change poll surfaces repeated page tokens with reset guidance" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{
                next_page_token: "loop-page",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Connect.poll(
               Drive.integration(),
               "google.drive.file.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "loop-token"
             )
  end

  defp write_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/drive.file"
    ]
  end

  defp read_content_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/drive.readonly"
    ]
  end

  defp full_drive_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/drive"
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
      ])

    profile = Keyword.get(opts, :profile, :user)
    owner_type = Keyword.get(opts, :owner_type, :app_user)
    owner_id = Keyword.get(opts, :owner_id, "user_1")

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: owner_type,
        owner_id: owner_id,
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: profile,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_drive_client: FakeDriveClient},
        scopes: scopes
      })

    {context, lease}
  end
end
