defmodule Jido.Connect.Google.Drive.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Drive tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.drive.files.list",
    "google.drive.file.get",
    "google.drive.file.export",
    "google.drive.file.download",
    "google.drive.permissions.list",
    "google.drive.permission.get",
    "google.drive.revisions.list",
    "google.drive.revision.get",
    "google.drive.comments.list",
    "google.drive.comment.get",
    "google.drive.replies.list",
    "google.drive.reply.get",
    "google.drive.shared_drives.list",
    "google.drive.shared_drive.get",
    "google.drive.file.changed",
    "google.drive.file.changed.push"
  ]

  @watch_tools @readonly_tools ++
                 [
                   "google.drive.changes.watch",
                   "google.drive.file.watch",
                   "google.drive.channel.stop"
                 ]

  @file_writer_tools @readonly_tools ++
                       [
                         "google.drive.file.create",
                         "google.drive.folder.create",
                         "google.drive.file.copy",
                         "google.drive.file.update"
                       ]

  @doc "Returns all built-in Google Drive catalog packs."
  def all, do: [readonly(), file_writer(), watch()]

  @doc "Read-only Drive metadata, content, permissions, and change polling pack."
  def readonly do
    Pack.new!(%{
      id: :google_drive_readonly,
      label: "Google Drive read-only",
      description:
        "Read Drive metadata, file content, comments, permissions, shared drives, and change events without mutation tools.",
      filters: %{provider: :google_drive},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_drive, risk: :read}
    })
  end

  @doc "Common Drive file writer pack, excluding deletes and permission sharing."
  def file_writer do
    Pack.new!(%{
      id: :google_drive_file_writer,
      label: "Google Drive file writer",
      description:
        "Read and mutate Drive file metadata. Excludes deletes, collaboration changes, and shared-drive administration.",
      filters: %{provider: :google_drive},
      allowed_tools: @file_writer_tools,
      metadata: %{
        package: :jido_connect_google_drive,
        excludes: [
          "google.drive.file.delete",
          "google.drive.permission.create",
          "google.drive.permission.update",
          "google.drive.permission.delete",
          "google.drive.revision.update",
          "google.drive.revision.delete",
          "google.drive.comment.create",
          "google.drive.comment.update",
          "google.drive.comment.delete",
          "google.drive.reply.create",
          "google.drive.reply.update",
          "google.drive.reply.delete",
          "google.drive.shared_drive.create",
          "google.drive.shared_drive.update",
          "google.drive.shared_drive.delete",
          "google.drive.shared_drive.hide",
          "google.drive.shared_drive.unhide"
        ]
      }
    })
  end

  @doc "Drive watch channel lifecycle pack for push notification setup."
  def watch do
    Pack.new!(%{
      id: :google_drive_watch,
      label: "Google Drive watch",
      description:
        "Read Drive metadata, discover file-change webhooks, and manage Drive push notification channels.",
      filters: %{provider: :google_drive},
      allowed_tools: @watch_tools,
      metadata: %{package: :jido_connect_google_drive, risk: :write}
    })
  end
end
