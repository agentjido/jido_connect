# Jido Connect Google Drive

Google Drive provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Drive-specific DSL, handlers,
schemas, normalized structs, and tests in this package.

## Actions

- `google.drive.about.get`
- `google.drive.files.list`
- `google.drive.file.get`
- `google.drive.file.create`
- `google.drive.folder.create`
- `google.drive.file.copy`
- `google.drive.file.update`
- `google.drive.file.export`
- `google.drive.file.download`
- `google.drive.file.delete`
- `google.drive.permissions.list`
- `google.drive.permission.create`
- `google.drive.revisions.list`
- `google.drive.revision.get`
- `google.drive.file.watch`
- `google.drive.changes.watch`
- `google.drive.channel.stop`

## Triggers

- `google.drive.file.changed`
- `google.drive.file.changed.webhook`

The change poller initializes from Drive `startPageToken` without replaying
history, then advances checkpoints through `nextPageToken` or
`newStartPageToken`.

The webhook trigger is metadata-only. Hosts create channels with
`google.drive.file.watch` or `google.drive.changes.watch`, store the returned
channel/resource ids and optional token, then normalize incoming Drive push
headers with `Jido.Connect.Google.Drive.Webhook`.

## File Filters

`google.drive.files.list` accepts both native Google Drive `query` strings and a
provider-specific `filter` map. The filter is compiled only inside this package,
not in `jido_connect` core:

```elixir
%{
  parent_id: "root",
  mime_type: "application/pdf",
  trashed: false,
  name_contains: "Budget"
}
```

## Catalog Packs

- `:google_drive_readonly` includes metadata reads, content reads, permission
  reads, revisions, and file-change polling/webhook metadata.
- `:google_drive_file_writer` adds common file metadata writes and folder
  creation plus watch channel lifecycle actions. It intentionally excludes
  destructive delete and permission sharing.

```elixir
Jido.Connect.Catalog.search_tools("drive",
  modules: [Jido.Connect.Google.Drive],
  packs: Jido.Connect.Google.Drive.catalog_packs(),
  pack: :google_drive_file_writer
)
```

## Scopes

The connector prefers narrow Drive scopes:

- `drive.metadata.readonly` for metadata reads, permission listing, and change
  polling/watch channel metadata.
- `drive.readonly` for file content export/download.
- `drive.file` for app-managed file writes, deletes, and permission creation.
