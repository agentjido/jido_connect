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
- `google.gmail.label.get`
- `google.gmail.messages.list`
- `google.gmail.message.get`
- `google.gmail.threads.list`
- `google.gmail.thread.get`
- `google.gmail.drafts.list`
- `google.gmail.draft.get`
- `google.gmail.history.list`
- `google.gmail.message.attachment.get`
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

- `:google_gmail_metadata` includes read-only profile, label list, message, thread,
  history, received-message poll, and mailbox-changed webhook metadata tools.
- `:google_gmail_triage` adds watch lifecycle, label get, attachment get, label
  creation and update, message/thread label mutation, and reversible
  trash/untrash workflows. It intentionally excludes send, draft, and permanent
  delete tools.
- `:google_gmail_send` adds message send and non-destructive draft workflows
  plus webhook metadata. It intentionally excludes label mutation, attachment,
  and delete tools.
- `:google_gmail_destructive` exposes explicit draft, label, message, and
  thread delete or trash operations behind destructive action metadata.

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
- `gmail.readonly` or `gmail.modify` can satisfy metadata-read tools when a
  host already has broader grants.
- `gmail.readonly` or `gmail.modify` for label get and attachment body retrieval.
- `gmail.send` for direct send, with `gmail.compose` or `gmail.modify` accepted
  when already granted.
- `gmail.compose` for draft list/get/create/update/send/delete, with
  `gmail.modify` accepted when
  already granted.
- `gmail.modify` for message/thread label application, batch modification,
  and reversible trash/untrash workflows.
- `https://mail.google.com/` only for permanent message and thread deletes.
