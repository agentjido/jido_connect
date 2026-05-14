defmodule Jido.Connect.Google.Drive.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Drive tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.drive.files.list",
    "google.drive.file.get",
    "google.drive.file.export",
    "google.drive.file.download",
    "google.drive.permissions.list",
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
        "Read Drive metadata, file content, permissions, and change events without mutation tools.",
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
        "Read and mutate Drive file metadata. Excludes deletes and permission sharing.",
      filters: %{provider: :google_drive},
      allowed_tools: @file_writer_tools,
      metadata: %{
        package: :jido_connect_google_drive,
        excludes: ["google.drive.file.delete", "google.drive.permission.create"]
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
