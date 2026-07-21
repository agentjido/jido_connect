# Jido Connect Calendly

`jido_connect_calendly` is the Calendly provider package for `jido_connect`.

It includes:

- `Jido.Connect.Calendly`, a Spark-authored provider that compiles into Jido tools
- Calendly event type, scheduled event, and invitee read actions
- Calendly invitee cancellation and webhook lifecycle actions
- Webhook triggers for invitee created and canceled events
- Webhook verification and normalization in `Jido.Connect.Calendly.Webhook`
- Catalog packs for scoped tool discovery (`:calendly_reader`, `:calendly_webhook`,
  `:calendly_full`)
- REST client helpers in `Jido.Connect.Calendly.Client`
- Transport boundary in `Jido.Connect.Calendly.Client.Transport`
- Response normalization in `Jido.Connect.Calendly.Client.Response`

The Spark DSL declaration lives in
`lib/jido_connect/calendly.ex`. Provider handlers live under
`lib/jido_connect/calendly/handlers/`.

## Status

This is an **experimental** scaffold. Additional action fragments, trigger
fragments, normalized structs, and webhook support may be added in subsequent
waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_calendly, "~> 0.8"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles:

- **Personal Access Token** (`:personal_access_token`): Calendly PAT passed as
  a Bearer token. Recommended for development and CI.
- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE against Calendly's identity provider.

## OAuth Scopes

| Scope | Description |
|---|---|
| `view` | Read access to user, event type, and scheduling data |
| `edit` | Write access to event types and invitees |
| `webhook` | Manage webhook subscriptions |

Read-only operations should use the `view` scope when possible. Mutations
require `edit` and webhook management requires the `webhook` scope.

## Actions

### Read Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `calendly.event_types.list` | list | read | List event types |
| `calendly.event_types.get` | get | read | Get event type by URI |
| `calendly.scheduled_events.list` | list | read | List scheduled events |
| `calendly.scheduled_events.get` | get | read | Get scheduled event by URI |
| `calendly.invitees.list` | list | read | List invitees for an event |
| `calendly.invitees.get` | get | read | Get invitee by event and URI |

### Cancellation & Webhook Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `calendly.invitees.cancel` | update | external_write | Cancel an invitee |
| `calendly.webhooks.create` | create | external_write | Create webhook subscription |
| `calendly.webhooks.list` | list | read | List webhook subscriptions |
| `calendly.webhooks.delete` | delete | external_write | Delete webhook subscription |

## Webhook Triggers

The provider declares webhook triggers for real-time invitee events:

| Trigger ID | Resource | Events |
|---|---|---|
| `calendly.invitee.created` | invitee | New booking confirmed |
| `calendly.invitee.canceled` | invitee | Booking canceled |

### Webhook Verification

`Jido.Connect.Calendly.Webhook` provides pure helpers for:

- **Signature verification**: HMAC-SHA256 hex digest of the raw body against the
  webhook signing key. The signature is sent in the `Calendly-Webhook-Signature`
  header. Use `compute_signature/2` to compute the digest and
  `verify_signature/2` for constant-time comparison.
- **Event normalization**: `normalize_event/1` converts a raw Calendly webhook
  payload (invitee.created or invitee.canceled) into a flat signal map with
  stable field names.
- **Batch normalization**: `normalize_events/1` processes a list of events.

### Webhook Event Fields

Invitee events produce signals with:

- `event_type` (`"invitee.created"` or `"invitee.canceled"`), `change_type`
- `invitee_uri`, `invitee_email`, `invitee_name`, `invitee_status`,
  `invitee_timezone`
- `event_uri`, `event_type_uri`, `event_type_name`
- `organization_uri`
- `cancel_url`, `reschedule_url`
- `questions_and_answers`
- `created_at`, `updated_at`, `time`

Canceled events additionally include:

- `canceled_by`, `cancellation_reason`

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:calendly_reader` | Event type, scheduled event, and invitee reads |
| `:calendly_webhook` | Webhook create, list, and delete |
| `:calendly_full` | Reader + cancellation + webhook lifecycle |

Triggers are subscribed to independently and are not listed in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("calendly",
  modules: [Jido.Connect.Calendly],
  packs: Jido.Connect.Calendly.catalog_packs(),
  pack: :calendly_reader
)

# Full access
Catalog.search_tools("calendly",
  modules: [Jido.Connect.Calendly],
  packs: Jido.Connect.Calendly.catalog_packs(),
  pack: :calendly_full
)
```

## API Boundaries

All Calendly API traffic uses
`Jido.Connect.Calendly.Client.Transport.api_request/2`, which builds bearer
requests against the configurable Calendly API v2 base URL
(`https://api.calendly.com`).

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, webhook normalization, triggers, and catalog packs
through injected fake clients and does **not** call live Calendly APIs.

### Environment Variables for Live Testing

```sh
export CALENDLY_PERSONAL_ACCESS_TOKEN="your-pat-here"
# Never commit these values to version control.
```

### Live Webhook Testing

To verify webhook delivery from a Calendly workspace:

1. Create a webhook subscription via `calendly.webhooks.create` pointing to
   your endpoint URL.
2. Configure the webhook signing key for signature verification.
3. Use `Jido.Connect.Calendly.Webhook.compute_signature/2` to compute the
   expected HMAC-SHA256 hex digest.
4. Use `Jido.Connect.Calendly.Webhook.verify_signature/2` to compare against
   the `Calendly-Webhook-Signature` header value in constant time.
5. Use `Jido.Connect.Calendly.Webhook.normalize_event/1` to normalize the
   accepted payload into a trigger signal.

Do not expose the webhook signing key or personal access token in logs or
public payloads.

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_calendly
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_calendly/test --no-deps-check
```
