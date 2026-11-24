# Jido Connect Gmail

Gmail provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Gmail-specific DSL, handlers,
schemas, normalized structs, privacy boundaries, and tests in this package.

## Privacy Boundary

Gmail data is sensitive by default. The connector classifies addresses,
subjects, snippets, headers, labels, and payload summaries as personal or
message content depending on the action. Normalized message, thread, and draft
structs intentionally avoid raw RFC822 bodies, Gmail `raw` payloads, and MIME
part `body.data` bytes. Message body and attachment bytes come only from
actions that declare content access, and the opt-in `:google_gmail_content`
catalog pack gathers those actions: `google.gmail.message.content.get` and
`google.gmail.thread.content.get` return full body text,
`google.gmail.message.attachment.get` returns Gmail's base64url-encoded
attachment `data` field, and `google.gmail.message.attachment.content.get`
returns the bytes of one attachment selected by MIME part ID.

## MIME Traversal

`Jido.Connect.Gmail.MIME.Traversal` walks the payload of a `format=full`
message without network access; its moduledoc describes the result, the
attachment manifest and the bounds. For `format=full`, Gmail returns text data
already converted to UTF-8, so an inline text part has `decoded: false` only
when its data is not valid UTF-8, and an inline `koi8-r` part arrives decoded.
`attachments.get` returns the original bytes, which
`decode_external_text_part/2` decodes as UTF-8, US-ASCII, ISO-8859-1,
ISO-8859-15 or Windows-1252, also under their IANA aliases; a `koi8-r` part
fetched that way keeps `decoded: false`. Gmail pads base64url data, and the
traversal accepts it with and without padding.

## Message Content

`google.gmail.message.content.get` takes a `message_id` and returns `message`,
a `Jido.Connect.Gmail.MessageContent`. `google.gmail.thread.content.get` takes
a `thread_id` and returns `thread`, a `Jido.Connect.Gmail.ThreadContent` that
holds every message of the thread, sent replies included, ordered by the
numeric value of Gmail's `internalDate`; messages with the same date keep
Gmail's order. Both read Gmail's `format=full` representation.

A message carries Gmail's IDs, labels and `internalDate`, every header with
repeats, the first `From`, `To`, `Cc`, `Bcc`, `Reply-To`, `Subject`, `Date`,
`Message-ID`, `In-Reply-To` and `References` values, its body text parts, the
attachment manifest and the enclosed `message/rfc822` messages, in the shapes
that the traversal documents. When Gmail stores a body text part behind an
`attachmentId`, the action fetches it with `attachments.get` and puts it back
in Gmail's part order. It never fetches a file attachment; pass a `part_id`
from the manifest to `google.gmail.message.attachment.content.get` for the
bytes. An inline forward keeps the quoted original inside its text parts.
A forward as attachment shows the original as an enclosed message, or as a
`message/rfc822` manifest entry when Gmail supplies no nested parts. Neither
result verifies a quoted sender or separates a comment from the original.

Text is never truncated; intake limits belong to the host. Each message is
walked with the traversal's default `max_depth` and `max_parts`, and the
thread input `max_messages`, default 100, bounds a thread. A longer thread
fails with reason `:thread_messages_exceeded`, and a failed fetch of a text
part fails the whole read. Neither returns partial content.

## Attachment Content

`google.gmail.message.attachment.content.get` takes a `message_id` and a
`part_id` and returns `attachment`, a `Jido.Connect.Gmail.AttachmentContent`.
Gmail's `partId` is the only part identity. The manifest of
`google.gmail.message.content.get` lists the part IDs to choose from: its
attachment entries and its enclosed messages. The action reads the message in
`format=full`, selects the part with the MIME traversal and requests
`attachments.get` only for a part without inline data, with the
`attachmentId` of the same response. Empty `body.data` next to an
`attachmentId` counts as no inline data. Both paths encode the IDs as single
path segments. The root of a message is selectable like any other part; the
root of a single-part message has the part ID `""`.

The result carries the message, thread and history IDs, `part_id`,
`attachment_id` when Gmail supplied one, `filename`, `mime_type`, `size`,
`disposition`, `content_id` and `data`, the base64url string that Gmail
returned, padded or not. `data` decodes to exactly `size` bytes, Gmail's count
of the original bytes. For an enclosed message the bytes are the whole
original, headers included. The connector does not extract text or apply a
format policy. There is no byte cap; the traversal's `max_depth` and
`max_parts` apply to the whole message, and intake limits belong to the host.

Errors name IDs, never data. An unknown part ID returns a validation error
with reason `:unknown_part_id`, and a body text part or a container one with
reason `:not_an_attachment`. A part with neither data nor `attachmentId`
returns a provider error with reason `:attachment_data_missing`; invalid
base64url and data of another length return `:invalid_base64url` and
`:attachment_size_mismatch`.

Gmail keeps a `text/*` part without a filename inline, also when its
disposition is `attachment`, and returns the data converted to UTF-8 while
`size` keeps the original count. Such a part has no `attachmentId`, so
`attachments.get` cannot fetch it, and Gmail returns its original bytes only
within the whole message in `format=raw`, which the action does not read. The
action therefore returns inline text only where the conversion cannot have
changed it: empty data, data of `size` bytes in a part declared as UTF-8, and
7-bit ASCII data of `size` bytes in a part that declares no charset, US-ASCII,
ISO-8859-1 to ISO-8859-10, ISO-8859-13 to ISO-8859-16, Windows-1250 to
Windows-1258, KOI8-R or KOI8-U, also under the aliases that
`Jido.Connect.Gmail.MIME.Charset` lists. Other inline text fails with reason
`:attachment_converted`: non-ASCII text in a charset other than UTF-8, and any
text in another charset such as UTF-16, whose UTF-8 form can keep the original
length with other bytes. In the live test account, Gmail kept unnamed binary
parts behind an `attachmentId` and returned unnamed ISO-8859-1, Windows-1252
and UTF-16LE text converted; the UTF-16LE text kept its length, so only its
charset shows the conversion.

## Outgoing Messages

`google.gmail.message.send`, `google.gmail.draft.create` and
`google.gmail.draft.update` build their message with
`Jido.Connect.Gmail.MIME.build_raw/1`. It trims recipients, the subject and
the body and emits one UTF-8 body part, HTML when both bodies are given. The
body goes out as `8bit` under `charset=UTF-8`.

A subject with a character outside ASCII goes out as RFC 2047 encoded words,
`=?UTF-8?B?...?=`, each holding at most 39 bytes of whole UTF-8 code points,
folded so that no line of the `Subject` header exceeds 76 characters. An
ASCII subject goes out unchanged, on one line. When the live test created a
draft with a raw UTF-8 subject, Gmail stored the subject garbled and the
`8bit` body with its bytes; sending was not tried with a raw subject.

A header value in the input must not break the line. After trimming, a CR or
LF in `subject`, `in_reply_to` or `references` returns a validation error with
reason `:invalid_header_value` and the field, so the value cannot add a header
such as `Bcc:`. `in_reply_to` and `references` are not trimmed, so a trailing break
fails too. They must be `nil` or a string; `nil` and `""` leave the header out,
and any other value, such as a list, fails with the same reason. A recipient
with a break inside fails the address pattern with `:invalid_recipient`.
Either way the action makes no provider call, and the header error does not
repeat the value.

## Actions

- `google.gmail.profile.get`
- `google.gmail.labels.list`
- `google.gmail.label.get`
- `google.gmail.messages.list`
- `google.gmail.message.get`
- `google.gmail.threads.list`
- `google.gmail.thread.get`
- `google.gmail.drafts.list`
- `google.gmail.draft.get`
- `google.gmail.history.list`
- `google.gmail.message.attachment.get`
- `google.gmail.message.content.get`
- `google.gmail.thread.content.get`
- `google.gmail.message.attachment.content.get`
- `google.gmail.watch.start`
- `google.gmail.watch.stop`
- `google.gmail.message.send`
- `google.gmail.draft.create`
- `google.gmail.draft.update`
- `google.gmail.draft.send`
- `google.gmail.draft.delete`
- `google.gmail.label.create`
- `google.gmail.label.update`
- `google.gmail.label.delete`
- `google.gmail.message.labels.apply`
- `google.gmail.messages.batch_modify`
- `google.gmail.message.trash`
- `google.gmail.message.untrash`
- `google.gmail.message.delete`
- `google.gmail.messages.batch_delete`
- `google.gmail.thread.modify`
- `google.gmail.thread.trash`
- `google.gmail.thread.untrash`
- `google.gmail.thread.delete`

## Triggers

- `google.gmail.message.received`
- `google.gmail.message.changed`
- `google.gmail.mailbox.changed`

The message poller initializes from the Gmail profile `historyId` without
replaying history, then drains Gmail history pages for `messageAdded` records
and advances the checkpoint to the returned mailbox `historyId`.

`google.gmail.message.changed` polls the same history the same way for
permanent deletions and label changes. It requests the `historyTypes`
`messageDeleted`, `labelAdded` and `labelRemoved` from the stored checkpoint,
every 300,000 ms by default, with `page_size` (default 100) as `maxResults` and
an optional `label_id`, unset by default, as Gmail's `labelId` filter. Each
deleted message and each label change of a message is one signal with
`change_type` (`message_deleted`, `label_added` or `label_removed`),
`message_id`, `thread_id`, `history_id`, `changed_label_ids` and `label_ids`.
`history_id` is the ID of the history record, `changed_label_ids` the labels
the change added or removed, and `label_ids` the message's labels after the
change as Gmail reports them. Signals carry no subject, snippet, headers or
body. Hosts dedupe on `history_id`, `message_id` and `change_type`. Records
without one of the three changes, which Gmail returns as well, yield no
signal. Like the other metadata reads, the trigger needs `gmail.metadata`, or
the first of `gmail.modify`, `gmail.readonly` and `https://mail.google.com/`
that the connection holds.

Gmail reports the usual mailbox actions as distinct changes. The live tests
recorded the following, unless noted:

- Archive removes `INBOX`: one `label_removed` signal with
  `changed_label_ids: ["INBOX"]`.
- Moving a message to Trash adds `TRASH`: a `label_added` signal with
  `changed_label_ids: ["TRASH"]`. Trash also takes a message out of the
  inbox: Gmail's answer to trashing an inbox message no longer lists `INBOX`.
  Not recorded: on 2026-11-02 Gmail wrote that removal as a second history
  record, so a `label_removed` signal with `["INBOX"]` followed.
- Restoring from Trash removes `TRASH`: a `label_removed` signal with
  `["TRASH"]`. Gmail does not add `INBOX` back; its answer to restoring a
  message that Trash took out of the inbox lists no `INBOX`.
- Permanent delete, which bypasses Trash, is a `message_deleted` signal with
  empty `changed_label_ids`. `label_ids` holds the labels that Gmail reports
  with the deletion; the recorded message had none left, so it was empty.

An expired or unknown history ID fails the poll with reason
`:checkpoint_expired`, and a repeated `nextPageToken` with
`:invalid_response`; both carry `checkpoint_reset` guidance to clear the
checkpoint and initialize again without replay.

The mailbox-changed webhook trigger is metadata-only and models Gmail Cloud
Pub/Sub push callbacks. Hosts remain responsible for Pub/Sub subscription
configuration and OIDC/token verification at the HTTP boundary. Use
`Jido.Connect.Gmail.Webhook.normalize_pubsub_push/1` after verification to
decode the Pub/Sub `message.data` payload into the trigger signal shape; webhook
dedupe is based on Gmail `history_id`.

## Catalog Packs

- `:google_gmail_metadata` includes read-only profile, label list, message,
  thread, and history tools.
- `:google_gmail_triage` adds watch lifecycle, label get, attachment get, label
  creation and update, message/thread label mutation, and untrash workflows. It
  excludes send, draft, trash, and permanent delete tools.
- `:google_gmail_send` adds message send and non-destructive draft workflows
  and excludes label mutation, attachment, and delete tools.
- `:google_gmail_destructive` exposes trash and explicit draft, label, message,
  and thread delete operations behind destructive action metadata.
- `:google_gmail_content` is the opt-in read pack for message content. It adds
  `google.gmail.message.content.get`, `google.gmail.thread.content.get`,
  `google.gmail.message.attachment.get` and
  `google.gmail.message.attachment.content.get` to the metadata tools and
  excludes send, draft, label mutation, watch, trash, and delete tools.

```elixir
Jido.Connect.Catalog.search_tools("gmail",
  modules: [Jido.Connect.Gmail],
  packs: Jido.Connect.Gmail.catalog_packs(),
  pack: :google_gmail_triage
)
```

## Tool Availability

Generated plugin availability covers every Gmail action and trigger, including
mailbox polling and webhook metadata. Hosts can pass a durable connection plus
optional allow lists to see `:available`, `:missing_scopes`,
`:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.Gmail.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.gmail.messages.list"],
  allowed_triggers: ["google.gmail.message.received"]
})
```

## Scopes

The connector prefers narrow Gmail scopes:

- `gmail.metadata` for profile, label list, metadata reads, received-message
  and message-change polling, history listing, and watch lifecycle operations.
- `gmail.labels` for label definition create, update, and delete operations.
- Metadata reads other than the label list need `gmail.metadata` only when
  the connection holds no broader grant. If it holds `gmail.modify`,
  `gmail.readonly` or `https://mail.google.com/`, the first of them in that
  order is required, and a lease narrowed to `gmail.metadata` fails with
  missing scopes. The label list keeps `gmail.metadata` whenever it is
  granted.
- `google.gmail.messages.list` and `google.gmail.threads.list` with a
  non-empty `query` need `gmail.readonly`, or an already granted
  `gmail.modify` or `https://mail.google.com/`, because Gmail rejects the `q`
  parameter under `gmail.metadata`. The rule follows what the client sends as
  `q`, so a query of whitespace counts as a search. Without a query, or with
  an empty one, both resolve like the other metadata reads.
- `gmail.readonly` or `gmail.modify` for label get, message and thread content,
  and attachment body retrieval by attachment ID or MIME part ID.
- `gmail.send` for direct send, with `gmail.compose` or `gmail.modify` accepted
  when already granted.
- `gmail.compose` for draft list/get/create/update/send/delete, with
  `gmail.modify` accepted when
  already granted.
- `gmail.modify` for message/thread label application, batch modification,
  and reversible trash/untrash workflows.
- `https://mail.google.com/` only for permanent message and thread deletes.
