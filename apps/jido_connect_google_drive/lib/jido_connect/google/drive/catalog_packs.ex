defmodule Jido.Connect.Google.Drive.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Drive tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.drive.about.get",
    "google.drive.files.list",
    "google.drive.file.get",
    "google.drive.file.export",
    "google.drive.file.download",
    "google.drive.permissions.list",
    "google.drive.revisions.list",
    "google.drive.revision.get",
    "google.drive.file.changed",
    "google.drive.file.changed.webhook"
  ]

  @file_writer_tools @readonly_tools ++
                       [
                         "google.drive.file.create",
                         "google.drive.folder.create",
                         "google.drive.file.copy",
                         "google.drive.file.update",
                         "google.drive.file.watch",
                         "google.drive.changes.watch",
                         "google.drive.channel.stop"
                       ]

  @doc "Returns all built-in Google Drive catalog packs."
  def all, do: [readonly(), file_writer()]

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
end
