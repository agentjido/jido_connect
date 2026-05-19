# jido_connect_microsoft_outlook

Microsoft Outlook Mail connector package for Jido Connect.

Builds on the shared `jido_connect_microsoft` foundation package for OAuth
profiles, Graph transport, pagination, scopes, and error normalization. This
package owns the Outlook Mail integration DSL, action catalog, scope resolver,
privacy boundaries, catalog packs, and env-gated live smoke hooks.

## Installation

This package is part of the `jido_connect` umbrella and depends on
`jido_connect` and `jido_connect_microsoft`.

```elixir
def deps do
  [
    {:jido_connect_microsoft_outlook, in_umbrella: true}
  ]
end
```

## Usage

```elixir
# Get the integration spec
spec = Jido.Connect.MicrosoftOutlook.integration()

# List declared actions
spec.actions

# List catalog packs
Jido.Connect.MicrosoftOutlook.catalog_packs()
```

## Architecture

- **Integration DSL** – Declares the `microsoft_outlook` provider with mail
  actions, auth profiles reused from the Microsoft foundation, and catalog
  metadata.
- **Scope Resolver** – Maps action ids to required Microsoft Graph mail scopes
  (`Mail.Read`, `Mail.ReadBasic`, `Mail.ReadWrite`, `Mail.Send`,
  `MailboxSettings.Read`) with least-privilege resolution against existing
  grants.
- **Catalog Packs** – Curated tool surfaces (metadata, triage, send,
  destructive) for host policy enforcement.
- **Action Handlers** – Each handler calls Microsoft Graph endpoints through
  the shared `Jido.Connect.Microsoft.Transport` module and normalizes responses
  through the package normalizer.
- **Normalizer** – Transforms Microsoft Graph `message`, `mailFolder`,
  `recipient`, and `fileAttachment` payloads into stable Zoi-backed structs
  with privacy-safe body summaries.
- **Privacy Boundary** – Body content, raw MIME, and base64 attachment bytes
  are intentionally excluded from normalized structs. See "Privacy Boundary"
  below.

## Actions

### Read

| Action ID | Description | Classification | Scopes |
|---|---|---|---|
| `microsoft.outlook.profile.get` | Fetch authenticated user profile | personal_data | MailboxSettings.Read |
| `microsoft.outlook.messages.list` | List message summaries from a folder | message_content | Mail.Read |
| `microsoft.outlook.message.get` | Fetch a single message by id | message_content | Mail.Read |
| `microsoft.outlook.folders.list` | List mail folders | personal_data | Mail.Read |
| `microsoft.outlook.folder.get` | Fetch a single folder by id | personal_data | Mail.Read |

### Write

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.outlook.message.send` | Send a new message | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.draft.create` | Create a draft message | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.draft.update` | Update an existing draft | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.draft.send` | Send a draft message | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.message.reply` | Reply to a message | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.message.reply_all` | Reply-all to a message | message_content | required_for_ai | Mail.Send |
| `microsoft.outlook.message.move` | Move message between folders | message_content | required_for_ai | Mail.ReadWrite |

### Destructive

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.outlook.message.delete` | Permanently delete a message | message_content | always | Mail.ReadWrite |
| `microsoft.outlook.draft.delete` | Delete a draft message | message_content | always | Mail.ReadWrite |

## Privacy Boundary

Outlook Mail data is sensitive by default. The connector classifies message
subjects, body previews, recipient addresses, and attachment metadata as
personal data or message content depending on the action. Normalized message
structs intentionally avoid full body HTML/text content, raw MIME data, and
base64 attachment bytes:

- **Body summaries** contain only `content_type` and `body_size` — never the
  raw body string.
- **Attachment metadata** includes `attachment_id`, `name`, `content_type`,
  `size`, and `is_inline` — never `contentBytes`.
- **Recipient structs** flatten the nested Graph `emailAddress` object into
  `name` and `address` fields only.

The `Jido.Connect.MicrosoftOutlook.Privacy` module documents which fields
carry message content versus personal data and provides a `raw_body_key?/1`
guard for filtering sensitive keys.

## Catalog Packs

- **`:microsoft_outlook_metadata`** — Read-only profile, message list, and
  folder metadata. No mutation, send, or delete tools.
- **`:microsoft_outlook_triage`** — Adds message get, folder get, and message
  move. Excludes send, draft, and permanent delete tools.
- **`:microsoft_outlook_send`** — Adds message send, draft create/update/send,
  and reply/reply-all. Excludes move and delete tools.
- **`:microsoft_outlook_destructive`** — Adds permanent message and draft
  delete operations.

```elixir
Jido.Connect.Catalog.search_tools("outlook",
  modules: [Jido.Connect.MicrosoftOutlook],
  packs: Jido.Connect.MicrosoftOutlook.catalog_packs(),
  pack: :microsoft_outlook_triage
)
```

## Tool Availability

Generated plugin availability covers every Outlook action. Hosts can pass a
durable connection plus optional allow lists to see `:available`,
`:missing_scopes`, `:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.MicrosoftOutlook.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["microsoft.outlook.messages.list"]
})
```

## Scopes

The connector prefers narrow Microsoft Graph scopes:

- `MailboxSettings.Read` for profile retrieval.
- `Mail.Read` for message and folder listing and retrieval. `Mail.ReadWrite`
  can satisfy read tools when a host already has broader grants.
- `Mail.ReadBasic` can satisfy metadata reads when granted.
- `Mail.Send` for send, draft, and reply operations. `Mail.ReadWrite` is
  accepted when already granted.
- `Mail.ReadWrite` for message move and permanent delete operations.

## Live Smoke Tests

Env-gated read-only live smoke hooks exercise real Microsoft Graph API calls
against the authenticated user's mailbox. These tests are **excluded by
default** and require a valid `MICROSOFT_ACCESS_TOKEN` environment variable.

```sh
MICROSOFT_ACCESS_TOKEN="eyJ..." \
  mix test test/jido_connect/microsoft_outlook/live_smoke_test.exs --include live_smoke
```

Optional fixture ids for deeper smoke coverage:

- `MICROSOFT_OUTLOOK_MESSAGE_ID` — Fetches a specific message when set.

### Safety

- All live smoke tests are read-only — no messages are created, sent, moved,
  or deleted.
- No tokens, secrets, or credential material are logged or exposed in test
  output.
- Tests skip automatically when `MICROSOFT_ACCESS_TOKEN` is not set.

## .env.example Fixture Placeholders

The root `.env.example` file includes the following Microsoft Graph and Outlook
Mail fixture placeholders for local smoke testing:

```sh
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=
MICROSOFT_TENANT_ID=common
MICROSOFT_REDIRECT_URI=http://localhost:4000/integrations/microsoft/oauth/callback
MICROSOFT_ACCESS_TOKEN=
MICROSOFT_REFRESH_TOKEN=
MICROSOFT_USER_ID=me
MICROSOFT_OUTLOOK_MESSAGE_ID=
MICROSOFT_OUTLOOK_FOLDER_ID=
```

## License

MIT
