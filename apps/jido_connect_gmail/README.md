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
part `body.data` bytes. Attachment body access is isolated to
`google.gmail.message.attachment.get`, which explicitly returns Gmail's
base64url-encoded attachment `data` field.

## Actions

- `google.gmail.profile.get`
- `google.gmail.labels.list`
- `google.gmail.messages.list`
- `google.gmail.message.get`
- `google.gmail.threads.list`
- `google.gmail.thread.get`
- `google.gmail.history.list`
- `google.gmail.message.attachment.get`
- `google.gmail.watch.start`
- `google.gmail.watch.stop`
- `google.gmail.message.send`
- `google.gmail.draft.create`
- `google.gmail.draft.send`
- `google.gmail.label.create`
- `google.gmail.message.labels.apply`

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

- `:google_gmail_metadata` includes read-only profile, label, message, thread,
  history, received-message poll, and mailbox-changed webhook metadata tools.
- `:google_gmail_triage` adds watch lifecycle, attachment get, label creation,
  and message label mutation. It intentionally excludes send and draft tools.
- `:google_gmail_send` adds message send and draft workflows plus webhook
  metadata. It intentionally excludes label mutation and attachment tools.

```elixir
Jido.Connect.Catalog.search_tools("gmail",
  modules: [Jido.Connect.Gmail],
  packs: Jido.Connect.Gmail.catalog_packs(),
  pack: :google_gmail_triage
)
```

## Scopes

The connector prefers narrow Gmail scopes:

- `gmail.metadata` for profile, labels, metadata reads, received-message
  polling, history listing, and watch lifecycle operations.
- `gmail.readonly` or `gmail.modify` can satisfy metadata-read tools when a
  host already has broader grants.
- `gmail.readonly` or `gmail.modify` for attachment body retrieval.
- `gmail.send` for direct send, with `gmail.compose` or `gmail.modify` accepted
  when already granted.
- `gmail.compose` for draft create/send, with `gmail.modify` accepted when
  already granted.
- `gmail.modify` for label creation and label application/removal.
