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
`google.gmail.thread.content.get` return full body text, and
`google.gmail.message.attachment.get` returns Gmail's base64url-encoded
attachment `data` field.

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
in Gmail's part order. It never fetches a file attachment; pass an
`attachment_id` from the manifest to `google.gmail.message.attachment.get` for
the bytes. An inline forward keeps the quoted original inside its text parts.
A forward as attachment shows the original as an enclosed message, or as a
`message/rfc822` manifest entry when Gmail supplies no nested parts. Neither
result verifies a quoted sender or separates a comment from the original.

Text is never truncated; intake limits belong to the host. Each message is
walked with the traversal's default `max_depth` and `max_parts`, and the
thread input `max_messages`, default 100, bounds a thread. A longer thread
fails with reason `:thread_messages_exceeded`, and a failed fetch of a text
part fails the whole read. Neither returns partial content.

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
- `google.gmail.mailbox.changed`

The message poller initializes from the Gmail profile `historyId` without
replaying history, then drains Gmail history pages for `messageAdded` records
and advances the checkpoint to the returned mailbox `historyId`.

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
  `google.gmail.message.content.get`, `google.gmail.thread.content.get` and
  `google.gmail.message.attachment.get` to the metadata tools and excludes
  send, draft, label mutation, watch, trash, and delete tools.

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
  polling, history listing, and watch lifecycle operations.
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
  and attachment body retrieval.
- `gmail.send` for direct send, with `gmail.compose` or `gmail.modify` accepted
  when already granted.
- `gmail.compose` for draft list/get/create/update/send/delete, with
  `gmail.modify` accepted when
  already granted.
- `gmail.modify` for message/thread label application, batch modification,
  and reversible trash/untrash workflows.
- `https://mail.google.com/` only for permanent message and thread deletes.
