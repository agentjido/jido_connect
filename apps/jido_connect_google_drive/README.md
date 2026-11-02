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

## Resolving Links, Resource Keys and Shortcuts

`Jido.Connect.Google.Drive.Link.parse/1` turns a Drive or Docs link into a file
ID and, when the link carries a `resourcekey` query parameter, a resource key.
It makes no HTTP request. It accepts these `https` shapes:

- `drive.google.com/file/d/<id>`, optionally followed by `/view`, `/edit` or
  `/preview`
- `drive.google.com/open?id=<id>`
- `drive.google.com/drive/folders/<id>` and `drive.google.com/drive/u/<n>/folders/<id>`
- `docs.google.com/{document,spreadsheets,presentation}/d/<id>/...`, also with
  `/u/<n>` before `/d`

"Publish to the web" links such as
`docs.google.com/spreadsheets/d/e/<token>/pubhtml` carry a publish token
instead of a file ID and are rejected.

Other query parameters and the fragment are ignored. Other hosts and shapes,
`http`, missing or conflicting IDs and malformed or conflicting resource keys
return a `Jido.Connect.Error.ValidationError` with reason
`:unsupported_drive_link`, `:missing_file_id`, `:conflicting_file_id` or
`:invalid_resource_key`. The error does not contain the link.

The result uses the input names of the file actions, so it can be passed on
directly:

```elixir
{:ok, link} =
  Jido.Connect.Google.Drive.Link.parse(
    "https://drive.google.com/file/d/1AbC/view?usp=sharing&resourcekey=0-XyZ"
  )

# link == %{file_id: "1AbC", resource_key: "0-XyZ"}
Jido.Connect.invoke(Jido.Connect.Google.Drive, "google.drive.file.get", link,
  context: context,
  credential_lease: lease
)
```

`google.drive.file.get`, `google.drive.file.export` and
`google.drive.file.download` take an optional `resource_key`. With it, that
request sends `X-Goog-Drive-Resource-Keys: <fileId>/<resourceKey>`, which Drive
needs for some link-shared files. An empty `resource_key` counts as absent. A
key, or a file ID sent with a key, that contains characters other than
letters, digits, `-` and `_` returns a `ValidationError` with reason
`:invalid_resource_key` or `:invalid_file_id` before any request, because `,`
and `/` would change the header's pairs. The key is never sent as a query
parameter and does not appear in returned error details.

The default file metadata projection, `Fields.file_metadata()`, requests
`resourceKey` and `shortcutDetails(targetId,targetMimeType,targetResourceKey)`.
Normalized files carry them as `resource_key`, `shortcut_target_id`,
`shortcut_target_mime_type` and `shortcut_target_resource_key`; fields that
Drive omits stay `nil`. A shortcut is returned as the shortcut file itself and
is not followed. To read the target, call `google.drive.file.get` with
`shortcut_target_id` and, if present, `shortcut_target_resource_key` as
`resource_key`. Optional action inputs reject `nil`, so leave `resource_key`
out when the target has no key:

```elixir
target_input =
  case shortcut.shortcut_target_resource_key do
    nil -> %{file_id: shortcut.shortcut_target_id}
    key -> %{file_id: shortcut.shortcut_target_id, resource_key: key}
  end

Jido.Connect.invoke(Jido.Connect.Google.Drive, "google.drive.file.get", target_input,
  context: context,
  credential_lease: lease
)
```

## Listing Folder Contents

`google.drive.files.list` sends `query` to Drive as `q`. A query such as
`'<folderId>' in parents` returns the folder's direct children only, not the
files in its subfolders. The package has no recursive listing; a host that
needs a whole tree lists each subfolder itself.

Drive's `files.list` returns trashed files as well, unless the query adds
`trashed = false`:

```elixir
Jido.Connect.invoke(
  Jido.Connect.Google.Drive,
  "google.drive.files.list",
  %{query: "'#{folder_id}' in parents and trashed = false"},
  context: context,
  credential_lease: lease
)
```

A result with `next_page_token` has more pages. Pass the token back as
`page_token` until a result comes without it.

`incomplete_search` is Drive's `incompleteSearch` flag. `true` means Drive did
not search every document, so matching files may be missing from the result.
According to Google this happens when a search with `corpora: "allDrives"`
cannot cover every corpus; Google then recommends narrowing the search to the
`user` or `drive` corpus. The default field presets, `Fields.file_list()` and
`Fields.file_list_with_permissions()`, request the flag, and `false` is
returned as `false`. A caller-supplied `fields` is sent unchanged; when it does
not name `incompleteSearch`, the result has no `incomplete_search` key.

To follow a folder, poll the `google.drive.collection.changes` trigger once
with the folder ID as `collection_id` before the first listing. A poll without
a checkpoint returns no signals and Drive's current change position as its
checkpoint; it does not replay earlier changes. The host stores the
checkpoint, lists the folder and then polls from the stored checkpoint. A
change made between that first poll and the listing can show up in both, so
the host applies signals by `provider_record_id`, and a change the listing
already contains updates the same entry again.

Each signal carries `collection_match`: `"yes"` when the changed file is the
folder or lists it in `parents`, `"no"` when it does not, which includes a file
moved out of the folder, and `"unknown"` when Drive sends no file, as for a
removed one. As long as every poll continues from the checkpoint the previous
poll returned, the host does not have to list the folder again.

A poll that cannot continue from its checkpoint, for example because Drive
reports it expired (`reason: :checkpoint_expired`), returns an error whose
`details` carry `checkpoint_reset`. The host then clears the checkpoint and
polls again. That poll starts from Drive's current position without the
missed changes, so it takes the place of the first poll above, and the host
lists the folder again after it.

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
Fields.about_metadata()
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

- `:google_drive_readonly` includes account/quota metadata, file metadata reads,
  content reads, permission reads, revision reads, comment/reply reads,
  shared-drive reads, file-change polling, and file-change webhook metadata.
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
