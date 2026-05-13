defmodule Jido.Connect.Google.DriveTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.Google.Drive

  @drive_action_modules [
    Jido.Connect.Google.Drive.Actions.GetAbout,
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
    Jido.Connect.Google.Drive.Actions.ListRevisions,
    Jido.Connect.Google.Drive.Actions.GetRevision,
    Jido.Connect.Google.Drive.Actions.WatchFile,
    Jido.Connect.Google.Drive.Actions.WatchChanges,
    Jido.Connect.Google.Drive.Actions.StopChannel
  ]

  @drive_dsl_fragments [
    Jido.Connect.Google.Drive.Actions.About,
    Jido.Connect.Google.Drive.Actions.Read,
    Jido.Connect.Google.Drive.Actions.Write,
    Jido.Connect.Google.Drive.Actions.FileContent,
    Jido.Connect.Google.Drive.Actions.Permissions,
    Jido.Connect.Google.Drive.Actions.Revisions,
    Jido.Connect.Google.Drive.Actions.Watch,
    Jido.Connect.Google.Drive.Triggers.Changes
  ]

  defmodule FakeDriveClient do
    def get_about(%{}, "token") do
      {:ok,
       Drive.About.new!(%{
         user: %{"emailAddress" => "owner@example.com"},
         storage_quota: %{"limit" => "1000", "usage" => "25"}
       })}
    end

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

    def list_revisions(%{file_id: "file123", page_size: 100}, "token") do
      {:ok,
       %{
         revisions: [
           Drive.Revision.new!(%{
             revision_id: "rev123",
             mime_type: "application/pdf",
             modified_time: "2026-05-05T12:00:00Z"
           })
         ],
         next_page_token: "next-rev"
       }}
    end

    def get_revision(
          %{file_id: "file123", revision_id: "rev123", acknowledge_abuse: false},
          "token"
        ) do
      {:ok,
       Drive.Revision.new!(%{
         revision_id: "rev123",
         mime_type: "application/pdf",
         modified_time: "2026-05-05T12:00:00Z"
       })}
    end

    def watch_file(
          %{
            file_id: "file123",
            channel_id: "channel123",
            address: "https://example.com/webhooks/drive",
            type: "web_hook",
            supports_all_drives: false,
            acknowledge_abuse: false
          },
          "token"
        ) do
      {:ok,
       Drive.Channel.new!(%{
         channel_id: "channel123",
         resource_id: "resource123",
         resource_uri: "https://www.googleapis.com/drive/v3/files/file123",
         type: "web_hook",
         address: "https://example.com/webhooks/drive"
       })}
    end

    def watch_changes(
          %{
            page_token: "start-token",
            channel_id: "channel123",
            address: "https://example.com/webhooks/drive",
            type: "web_hook",
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.Channel.new!(%{
         channel_id: "channel123",
         resource_id: "resource123",
         resource_uri: "https://www.googleapis.com/drive/v3/changes",
         type: "web_hook",
         address: "https://example.com/webhooks/drive"
       })}
    end

    def stop_channel(%{channel_id: "channel123", resource_id: "resource123"}, "token") do
      {:ok, %{channel_id: "channel123", resource_id: "resource123", stopped?: true}}
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

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/drive.metadata.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.file" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/drive.readonly" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "google.drive.about.get",
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
             "google.drive.revisions.list",
             "google.drive.revision.get",
             "google.drive.file.watch",
             "google.drive.changes.watch",
             "google.drive.channel.stop"
           ]

    delete_action = Enum.find(spec.actions, &(&1.id == "google.drive.file.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always

    create_permission = Enum.find(spec.actions, &(&1.id == "google.drive.permission.create"))
    assert create_permission.risk == :external_write
    assert create_permission.confirmation == :always

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
              id: "google.drive.file.changed.webhook",
              kind: :webhook,
              dedupe: %{key: [:channel_id, :message_number]},
              verification: %{kind: :google_drive_channel_token}
            }} =
             Connect.trigger(spec, "google.drive.file.changed.webhook")
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
          module: Jido.Connect.Google.Drive.Sensors.FileChangedWebhook,
          name: "google_drive_file_changed_webhook",
          trigger_id: "google.drive.file.changed.webhook",
          signal_type: "google.drive.file.changed.webhook"
        }
      ],
      plugin_module: Jido.Connect.Google.Drive.Plugin,
      plugin_name: "google_drive"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Drive,
      readonly_pack: :google_drive_readonly,
      file_writer_pack: :google_drive_file_writer
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

  test "invokes Drive about through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              about: %{
                user: %{"emailAddress" => "owner@example.com"},
                storage_quota: %{"limit" => "1000", "usage" => "25"}
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.about.get",
               %{},
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

  test "invokes revisions through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              revisions: [
                %{
                  revision_id: "rev123",
                  mime_type: "application/pdf"
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

    assert {:ok, %{revision: %{revision_id: "rev123", mime_type: "application/pdf"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.revision.get",
               %{file_id: "file123", revision_id: "rev123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes watch lifecycle through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              channel: %{
                channel_id: "channel123",
                resource_id: "resource123",
                address: "https://example.com/webhooks/drive"
              }
            }} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.file.watch",
               %{
                 file_id: "file123",
                 channel_id: "channel123",
                 address: "https://example.com/webhooks/drive"
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{channel: %{channel_id: "channel123", resource_id: "resource123"}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.changes.watch",
               %{
                 page_token: "start-token",
                 channel_id: "channel123",
                 address: "https://example.com/webhooks/drive"
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{channel_id: "channel123", stopped?: true}}} =
             Connect.invoke(
               Drive.integration(),
               "google.drive.channel.stop",
               %{channel_id: "channel123", resource_id: "resource123"},
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

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
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
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_drive_client: FakeDriveClient},
        scopes: scopes
      })

    {context, lease}
  end
end
