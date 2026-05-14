# Jido Connect Google Drive

Google Drive provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Drive-specific DSL, handlers,
schemas, normalized structs, and tests in this package.

## Actions

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
- `google.drive.changes.watch`
- `google.drive.file.watch`
- `google.drive.channel.stop`

## Triggers

- `google.drive.file.changed`
- `google.drive.file.changed.push`

The change poller initializes from Drive `startPageToken` without replaying
history, then advances checkpoints through `nextPageToken` or
`newStartPageToken`.

The push trigger normalizes Google Drive `X-Goog-*` channel headers for
notifications created with `google.drive.changes.watch` or
`google.drive.file.watch`. Hosts remain responsible for verifying the HTTPS
delivery and the channel token before calling the normalizer.

Drive channels are provider resources. There is no automatic renew endpoint;
renewal is modeled as creating a replacement watch channel with a new
`channel_id`, then stopping the old channel with `google.drive.channel.stop`.

## Auth Profiles

Drive declares user OAuth and Google service-account profiles:

- `:user` for app-user OAuth authorization-code grants.
- `:service_account` for server-owned service accounts.
- `:domain_delegated_service_account` for Workspace domain-wide delegation.

Every Drive action and trigger advertises these profiles through the Jido
Connect action/trigger catalog. Service-account token minting lives in
`jido_connect_google`; Drive stays responsible for Drive-specific scopes and
endpoint behavior.

## Permission-Aware Field Projections

Google Drive `fields` expressions are provider-specific. `jido_connect` core
exposes action and catalog metadata so hosts can detect whether an action
supports `fields`, but it does not translate a universal embed-permissions
request across providers.

Use Drive-specific field presets when a host wants embedded permission metadata:

```elixir
alias Jido.Connect.Google.Drive.Fields

Fields.file_metadata()
Fields.file_with_permissions()
Fields.file_list_with_permissions()
Fields.permission_list()
```

For example, pass `Fields.file_list_with_permissions()` to
`google.drive.files.list` when you want Drive to return file metadata with
embedded permissions in one request. Use `google.drive.permissions.list` when you
prefer an explicit per-file permission request.

Hosts can discover support through action input metadata:

```elixir
{:ok, action} = Jido.Connect.action(Jido.Connect.Google.Drive, "google.drive.files.list")
fields = Enum.find(action.input, &(&1.name == :fields))

fields.metadata.presets.with_permissions
```

## Catalog Packs

- `:google_drive_readonly` includes metadata reads, content reads, permission
  reads, file-change polling, and file-change webhook metadata.
- `:google_drive_file_writer` adds common file metadata writes and folder
  creation. It intentionally excludes destructive delete and permission sharing.
- `:google_drive_watch` adds Drive push channel lifecycle actions for file and
  change notifications. It excludes file deletion and permission sharing.

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
  polling or push channel lifecycle.
- `drive.readonly` for file content export/download.
- `drive.file` for app-managed file writes, deletes, and permission creation.
