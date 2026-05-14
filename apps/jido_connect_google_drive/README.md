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
- `google.drive.permission.get`
- `google.drive.permission.update`
- `google.drive.permission.delete`
- `google.drive.revisions.list`
- `google.drive.revision.get`
- `google.drive.revision.update`
- `google.drive.revision.delete`
- `google.drive.comments.list`
- `google.drive.comment.get`
- `google.drive.comment.create`
- `google.drive.comment.update`
- `google.drive.comment.delete`
- `google.drive.replies.list`
- `google.drive.reply.get`
- `google.drive.reply.create`
- `google.drive.reply.update`
- `google.drive.reply.delete`
- `google.drive.shared_drives.list`
- `google.drive.shared_drive.get`
- `google.drive.shared_drive.create`
- `google.drive.shared_drive.update`
- `google.drive.shared_drive.delete`
- `google.drive.shared_drive.hide`
- `google.drive.shared_drive.unhide`
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
Fields.revision_list()
Fields.comment_list()
Fields.reply_list()
Fields.shared_drive_list()
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
  reads, revision reads, comment/reply reads, shared-drive reads, file-change
  polling, and file-change webhook metadata.
- `:google_drive_file_writer` adds common file metadata writes and folder
  creation. It intentionally excludes destructive delete, permission sharing,
  permission lifecycle mutations, revision lifecycle mutations, comment/reply
  mutations, and shared-drive administration.
- `:google_drive_watch` adds Drive push channel lifecycle actions for file and
  change notifications. It excludes file deletion, permission sharing,
  comment/reply mutation, and shared-drive administration.

```elixir
Jido.Connect.Catalog.search_tools("drive",
  modules: [Jido.Connect.Google.Drive],
  packs: Jido.Connect.Google.Drive.catalog_packs(),
  pack: :google_drive_file_writer
)
```

## Tool Availability

Generated plugin availability covers every Drive action and trigger, including
poll and webhook metadata. Hosts can pass a durable connection plus optional
allow lists to see `:available`, `:missing_scopes`, `:connection_required`, or
`:disabled_by_policy` per tool:

```elixir
Jido.Connect.Google.Drive.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.drive.files.list"],
  allowed_triggers: ["google.drive.file.changed"]
})
```

## Scopes

The connector prefers narrow Drive scopes:

- `drive.metadata.readonly` for metadata reads, permission listing, and change
  polling or push channel lifecycle.
- `drive.readonly` for file content export/download, comment/reply reads, and
  shared-drive reads.
- `drive.file` for app-managed file writes, deletes, permission lifecycle
  mutations, revision lifecycle mutations, and app-managed comment/reply
  mutations.
- `drive` for shared-drive administration such as create/update/delete,
  hide, and unhide.
