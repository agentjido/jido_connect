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
- `google.drive.file.upload`, up to 5,242,880 bytes, see
  [Uploading Files](#uploading-files)
- `google.drive.file.copy`
- `google.drive.file.update`
- `google.drive.file.export`, see
  [Limiting Content Bytes](#limiting-content-bytes)
- `google.drive.file.download`, the stored bytes unparsed, see
  [Downloading Files](#downloading-files) and
  [Limiting Content Bytes](#limiting-content-bytes)
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
- `google.drive.collection.changes`
- `google.drive.collection.changes.push`

Both change pollers initialize from Drive `startPageToken` without replaying
history, then advance checkpoints through `nextPageToken` or
`newStartPageToken`. `google.drive.file.changed` returns every change in the
change log it reads; `google.drive.collection.changes` returns file changes
with their relation to one folder, as described in
[Listing Folder Contents](#listing-folder-contents) and
[Added Files](#added-files).

The push triggers normalize Google Drive `X-Goog-*` channel headers.
`google.drive.file.changed.push` covers notifications of channels created with
`google.drive.changes.watch` or `google.drive.file.watch`,
`google.drive.collection.changes.push` those of `google.drive.collection.watch`.
Hosts remain responsible for verifying the HTTPS delivery and the channel token
before calling the normalizer.

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

## Starred Flag and Modification Time

`google.drive.file.get` and `google.drive.files.list` return Drive's `starred`
as `starred?` and `modifiedTime` as `modified_time`. The default projections,
`Fields.file_metadata()` and `Fields.file_list()`, request both.

`starred?` is the flag of the authorizing account, the account whose access
token makes the request. Drive keeps the flag per user, so the same file can be
starred for one account and not for another. When Drive omits `starred`,
`starred?` is `false`. Drive omits it, for example, when a caller-supplied
`fields` does not name it; that `false` does not say whether the file is
starred.

`modified_time` is Drive's `modifiedTime` string, unchanged. It is optional:
when Drive omits `modifiedTime`, `modified_time` is `nil`, also when
`created_time` is set. The value says when Drive last recorded a change to the
file. It identifies neither the editor nor an immutable revision. Drive can
leave `modifiedTime` unchanged after a Google Docs edit, so different contents
can carry the same value.

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

Each signal's `collection_match` says whether the changed file is in the
folder. [Added Files](#added-files) lists its values, and
[Removed Files](#removed-files) covers removals and the trash. As long as every
poll continues from the checkpoint the previous poll returned, the host does
not have to list the folder again.

A poll that cannot continue from its checkpoint, for example because Drive
reports it expired (`reason: :checkpoint_expired`), returns an error whose
`details` carry `checkpoint_reset`. The host then clears the checkpoint and
polls again. That poll starts from Drive's current position without the
missed changes, so it takes the place of the first poll above, and the host
lists the folder again after it.

## Added Files

Drive sends no creation event. A new file arrives as a change like any later
metadata change: in `google.drive.file.changed` with `change_type: "file"` and
`removed: false`, in `google.drive.collection.changes` with
`change_type: "updated"`. Drive merges the changes of one file between two
polls into one, so a file created and renamed in that time arrives once, with
its current metadata.

The evidence for a new file is its creation time, `file.created_time` in a
`google.drive.file.changed` signal and `record.created_at` in a
`google.drive.collection.changes` signal. A creation time after the host's
previous poll marks a file created since then. A file moved into a folder
keeps its original creation time.

`collection_match` relates the changed file to the folder in `collection_id`:

- `"yes"` when the file lists the folder in `parents`, which makes it a direct
  child, or when the change concerns the folder itself.
- `"no"` when the file's `parents` do not include the folder: a file in a
  subfolder, a file moved out of the folder, or a file elsewhere in Drive.
  Membership is not recursive. A host that follows a tree compares
  `record.parents` with the folder IDs it knows.
- `"unknown"` when Drive sends no file metadata, as for a removal. The one
  exception is a change to the folder itself that is not a removal, which is
  `"yes"`. Once the folder itself is gone, polls fail instead, as described
  under [Removed Files](#removed-files).

The two triggers take a folder or shared drive differently.
`google.drive.collection.changes` takes the folder ID as `collection_id`; its
config takes only `collection_id` and `page_size`. On every poll it reads the
folder with `supportsAllDrives=true`, rejects an ID that is not a folder and
derives the settings itself. For a folder in a shared drive it
reads that drive's change log with the drive's `drive_id`,
`include_items_from_all_drives: true` and `supports_all_drives: true`. For a
My Drive folder it reads the user's change log without shared-drive items.

`google.drive.file.changed` takes no folder. It reads the user's change log,
and the host sets the shared-drive settings itself. `drive_id` selects the
change log of one shared drive. `include_items_from_all_drives` and
`supports_all_drives` default to `false`, which leaves out shared-drive items;
reading a shared drive needs both set to `true`. With both `true`, the poll
also returns drive-level changes, described under
[Removed Files](#removed-files).

## Removed Files

A removal is a change with `removed: true`;
`google.drive.collection.changes` reports it as `removed?: true` with
`change_type: "deleted"`. According to Google's `changes` reference, `removed`
means that the file was removed from the user's list of changes, for example
by deletion or loss of access. For a file that someone shared with the user, a
removal can therefore mean that the access ended while the file still exists.
The signal does not say which.

A removal carries the file's ID and no metadata. `google.drive.file.changed`
returns `file_id`, `removed: true`, `time` and `change_type` without a `file`
key. `google.drive.collection.changes` returns `provider_record_id` with
`collection_match: "unknown"` and no `record`, so a host removes the file from
every folder view that holds it.

When a poll repeats a checkpoint, Drive merges a file's changes in that range
into one, so a removal can carry the `time` of an update the host already
received. The declared dedupe key of `google.drive.file.changed`,
`[:change_type, :file_id, :drive_id, :time]`, is then the same for both
signals. A host that deduplicates its signals across polls includes `removed`
in the key. `google.drive.collection.changes` tells the two apart by
`change_type`.

`google.drive.collection.changes` reads the folder in `collection_id` before
it reads the change log. Once that folder is deleted for good or the user can
no longer see it, Drive answers the folder read with 404, and the poll returns
a `Jido.Connect.Error.ProviderError` with `reason: :http_error` and
`status: 404` instead of signals. The error carries no `checkpoint_reset`, and
a poll without a checkpoint fails the same way. The removals of the folder and
of its files therefore do not arrive through this trigger; a removal of the
folder itself arrives as `"unknown"` only when Drive records it between the
folder read and the change read of one poll. A host that receives this error
treats the folder and its view as gone. If the user regains access, the host
follows the folder again with a first poll and a new listing, as described
under [Listing Folder Contents](#listing-folder-contents).

Moving a file to the trash is not a removal. Drive reports it as an update with
`removed: false` and the file's metadata, in which `trashed?` is `true`:
`file.trashed?` in `google.drive.file.changed`, `record.trashed?` in
`google.drive.collection.changes`. A trashed child keeps the folder in
`parents` and therefore arrives with `collection_match: "yes"`. A host whose
folder view leaves out trashed files, as the listing with `trashed = false`
above does, checks `trashed?` before it applies a `"yes"` signal and removes
the file from the view when it is `true`.

A drive-level change concerns a shared drive, for example its new name, and
names no file. Drive marks it with `changeType: "drive"` and sends it only when
`include_items_from_all_drives` and `supports_all_drives` are `true`.
`google.drive.file.changed` returns it with `change_type: "drive"`, `drive_id`,
`removed` and `time`, without `file_id` and `file`.
`google.drive.collection.changes` leaves drive-level changes out.

## Uploading Files

`google.drive.file.upload` creates a new file from bytes in one multipart
request and returns the created file's metadata as `file`. The bytes come as
`content`, raw bytes or UTF-8 text for in-process callers, or as
`content_base64` for JSON callers, never both. `mime_type` is the media type of
the bytes and defaults to `application/octet-stream`; `parents` names the
destination folder. `google.drive.file.create` creates metadata only and
uploads no content.

A file holds at most 5,242,880 bytes (5 MiB), counted after Base64 decoding.
For one byte more, the action returns a `Jido.Connect.Error.ValidationError`
with reason `:upload_too_large` before any request. Its message names the
limit and contains no file content. Larger files are not supported, because
the package has no resumable upload. The action also does not convert uploads
into native Google formats such as Google Docs or Sheets. `mime_type` takes the
media type of the bytes; Google Workspace types
(`application/vnd.google-apps.*`) are not supported values. The action does
not reject them before the request, and how Drive handles them is untested.

The scope resolver requires `drive.file` unless the connection holds `drive`.
According to Google, `drive.file` reaches only files and folders that the app
created or that the user opened with the app. Under `drive.file` the folder in
`parents` must therefore be such a folder, for example one created with
`google.drive.folder.create` through the same OAuth client. Uploading into any
other folder needs `drive`.

A repeated upload is not idempotent. The action sends no file ID
pre-generated with `files.generateIds`, which Drive would need to recognize a
repeat, and its action spec has `provider_idempotency?: false`. Every
successful request creates a new file, and Drive allows several files of the
same name in one folder. After a timeout the error carries
`delivery: :sent_outcome_unknown`, the file may exist, and
`Jido.Connect.Error.retry_guidance/1` returns `:do_not_retry`. The host keeps
its execution claim and looks for the file in the folder before it prepares a
new upload. Claims and replay rules are described under "Replay And Retry
Safety" in the `jido_connect` README.

## Downloading Files

`google.drive.file.download` returns the bytes Drive stores for a file that is
not a Google Workspace document, as `file_content`. The package does not parse
them, whatever their media type: a JSON file comes back as its text, not as a
map or a list. Valid UTF-8 without NUL bytes comes back as `content` with
`encoding: "utf-8"`; other bytes come back as `content_base64` with
`encoding: "base64"` and `binary: true`. `size` is the byte count, and
`mime_type` is the media type of the response without parameters, such as
`application/json`. Google Workspace documents need
`google.drive.file.export`, which converts them to a requested format.

## Limiting Content Bytes

`google.drive.file.export` and `google.drive.file.download` hold the whole
content in memory before they return it. Both take an optional `max_bytes`, a
non-negative integer, that bounds the bytes they read. Without it they read
the whole body; there is no default limit.

With `max_bytes`, the connector counts the content's bytes while they arrive
and stops reading before it collects the byte that would exceed the limit. A
`content-length` above the limit stops the read at the first chunk. Content
of exactly `max_bytes` bytes passes and comes back as it would without a
limit, with `size` at most `max_bytes`.

```elixir
Jido.Connect.invoke(
  Jido.Connect.Google.Drive,
  "google.drive.file.export",
  %{file_id: file_id, mime_type: "text/plain", max_bytes: 1_048_576},
  context: context,
  credential_lease: lease
)
```

Drive declares no size for an export: it converts the document while it
sends it, and the `size` it reports for a Google Docs document describes no
export of it. In the test account a document with a `size` of 1,024 exported
77 bytes as plain text. An export is therefore stopped only while it
arrives.

A download with `max_bytes` first reads the file's `size` through `files.get`
with `fields=size,mimeType`, the same `resource_key` and the same
`supports_all_drives`. When Drive declares more bytes than `max_bytes`, the
action fails without requesting the content. A file without a `size` goes on
to the content request, and so does a Google Workspace document, whose
download Drive refuses with 403. The count applies there as well, so content
longer than Drive declared is stopped too. The size read is one more request
for every download with `max_bytes`.

Content over the limit returns a `Jido.Connect.Error.ProviderError` with
`reason: :limit_exceeded` and `details.max_bytes`. The error holds no part of
the content, and `Jido.Connect.Error.retryable?/1` returns `false`, because a
repeated read meets the same limit. A negative `max_bytes` returns a
`ValidationError` before any request.

The count covers the bytes Drive sends. With `max_bytes`, Req neither asks
for a compressed body nor decompresses one, so these are the bytes the action
returns. Error responses, such as Google's JSON errors, do not count against
`max_bytes`.

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
