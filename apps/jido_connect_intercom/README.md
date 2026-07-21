# Jido Connect Intercom

`jido_connect_intercom` is the Intercom provider package for `jido_connect`.

It includes:

- `Jido.Connect.Intercom`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:intercom_reader`, `:intercom_editor`)

The Spark DSL declaration lives in
`lib/jido_connect/intercom.ex`.

## Status

This is an **experimental** package. Action fragments, normalized structs,
client transport, webhook triggers, and trigger handlers are implemented.

## Installation

```elixir
def deps do
  [
    {:jido_connect_intercom, "~> 0.8"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Intercom:

- **Access token** (`:access_token`): Intercom personal access token sent via
  the `Authorization: Bearer <token>` header. Recommended for server-to-server
  integrations, development, and CI.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Intercom authorization server. Grants scoped access on behalf of an Intercom
  workspace admin.

## Intercom Scopes

The provider declares Intercom permission scopes:

| Scope | Description |
|---|---|
| `contacts:read` | Read contacts |
| `contacts:write` | Create and update contacts |
| `conversations:read` | Read conversations |
| `conversations:write` | Reply to and update conversations |
| `companies:read` | Read companies |
| `companies:write` | Create and update companies |
| `admins:read` | Read admin information |
| `tags:read` | Read tags |
| `tags:write` | Create and apply tags |

Read scopes are included in the default scope set for the access token profile.
Write scopes should be requested only when mutation actions are needed.

## Actions

The provider declares 15 action tools across contacts, conversations, admins, and teams:

| Action ID | Verb | Description |
|---|---|---|
| `intercom.contact.list` | list | List contacts with pagination |
| `intercom.contact.search` | search | Search contacts by query |
| `intercom.contact.get` | get | Fetch a single contact by ID |
| `intercom.contact.create` | create | Create a new contact |
| `intercom.contact.update` | update | Update an existing contact |
| `intercom.contact.tag` | tag | Apply a tag to contacts |
| `intercom.contact.untag` | untag | Remove a tag from contacts |
| `intercom.conversation.list` | list | List conversations with pagination |
| `intercom.conversation.search` | search | Search conversations by query |
| `intercom.conversation.get` | get | Fetch a single conversation by ID |
| `intercom.conversation.reply` | reply | Reply to a conversation |
| `intercom.conversation.add_note` | note | Add an internal note to a conversation |
| `intercom.conversation.assign` | assign | Assign a conversation to an admin or team |
| `intercom.admin.list` | list | List admins (teammates) |
| `intercom.team.list` | list | List teams |

## Webhook Triggers

The provider ships with webhook triggers for conversation and contact events:

### Conversation Triggers

| Trigger ID | Topic | Description |
|---|---|---|
| `intercom.conversation.user.created` | `conversation.user.created` | New conversation started by a user |
| `intercom.conversation.admin.replied` | `conversation.admin.replied` | Admin replied to a conversation |
| `intercom.conversation.user.replied` | `conversation.user.replied` | User replied to a conversation |
| `intercom.conversation.admin.assigned` | `conversation.admin.assigned` | Conversation was assigned |
| `intercom.conversation.admin.closed` | `conversation.admin.closed` | Conversation was closed |

### Contact Triggers

| Trigger ID | Topic | Description |
|---|---|---|
| `intercom.contact.created` | `contact.created` | New contact was created |
| `intercom.contact.updated` | `contact.updated` | Contact was updated |
| `intercom.contact.deleted` | `contact.deleted` | Contact was deleted |

### Webhook Verification

Intercom signs webhook payloads with an HMAC-SHA256 hex digest sent in the
`X-Hub-Signature` header. The `Jido.Connect.Intercom.Webhook` module provides
pure helpers for verification and normalization:

```elixir
alias Jido.Connect.Intercom.Webhook

# Verify the signature (host computes from raw body + secret)
computed = Webhook.compute_signature(raw_body, webhook_secret)
:ok = Webhook.verify_signature(computed, signature_header)

# Normalize the event payload into a signal map
{:ok, signal} = Webhook.normalize_event(payload)
```

Triggers are subscribed to independently and are not included in catalog packs.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:intercom_reader` | read | Read-only Intercom queries |
| `:intercom_editor` | write | Reader + write tools |

Tool IDs are populated from action and trigger fragments.

Triggers are subscribed to independently and are not included in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("intercom",
  modules: [Jido.Connect.Intercom],
  packs: Jido.Connect.Intercom.catalog_packs(),
  pack: :intercom_reader
)

# Full editor access
Catalog.search_tools("intercom",
  modules: [Jido.Connect.Intercom],
  packs: Jido.Connect.Intercom.catalog_packs(),
  pack: :intercom_editor
)
```

## API Boundaries

All Intercom API traffic uses the dedicated transport boundary module
`Jido.Connect.Intercom.Client.Transport`. The base URL defaults to
`https://api.intercom.io`.

## Package Quality Gates

The Intercom package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_intercom
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_intercom/test --no-deps-check
```
