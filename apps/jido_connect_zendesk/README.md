# Jido Connect Zendesk

`jido_connect_zendesk` is the Zendesk provider package for `jido_connect`.

It includes:

- `Jido.Connect.Zendesk`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:zendesk_reader`, `:zendesk_editor`)
- OAuth2 helpers in `Jido.Connect.Zendesk.OAuth`
- REST client helpers in `Jido.Connect.Zendesk.Client`
- Transport boundary in `Jido.Connect.Zendesk.Client.Transport`
- Response normalization in `Jido.Connect.Zendesk.Client.Normalizer`
- Webhook verification and normalization in `Jido.Connect.Zendesk.Webhook`
- Trigger fragments for ticket and comment webhook events

The Spark DSL declaration lives in
`lib/jido_connect/zendesk.ex`. Provider handlers live under
`lib/jido_connect/zendesk/handlers/`.

## Status

This is an **experimental** package with read/write ticket actions and
webhook trigger support.

## Installation

```elixir
def deps do
  [
    {:jido_connect_zendesk, "~> 0.8"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Zendesk:

- **API token** (`:api_token`): Zendesk API token used with the email address
  via Basic authentication (`email/token:api_token`). Recommended for
  server-to-server integrations, development, and CI.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Zendesk authorization server. Grants scoped access on behalf of a Zendesk
  user.

## Zendesk Scopes

The provider declares Zendesk OAuth scopes:

| Scope | Description |
|---|---|
| `read` | Read tickets, users, and other resources |
| `write` | Create and update resources |
| `tickets:read` | Read tickets |
| `tickets:write` | Create and update tickets |
| `users:read` | Read user information |

Read scopes are included in both default scope sets. The `write` and
`tickets:write` scopes are optional for the OAuth2 profile and should be
requested only when mutation actions are needed.

See [`docs/zendesk_scope_matrix.md`](../../docs/zendesk_scope_matrix.md) for the
full action-to-scope mapping.

## Actions

| Action ID | Effect | Description |
|---|---|---|
| `zendesk.ticket.list` | read | List tickets with pagination |
| `zendesk.ticket.search` | read | Search tickets by query |
| `zendesk.ticket.get` | read | Get a single ticket by ID |
| `zendesk.ticket.create` | write | Create a new ticket |
| `zendesk.ticket.update` | write | Update ticket fields |
| `zendesk.ticket.comment.list` | read | List comments on a ticket |
| `zendesk.ticket.comment.add` | write | Add a comment to a ticket |
| `zendesk.user.list` | read | List users with role filter |
| `zendesk.organization.list` | read | List organizations |

## Webhook Triggers

The provider declares two webhook triggers for real-time ticket event
notifications:

| Trigger ID | Events | Signal |
|---|---|---|
| `zendesk.ticket.changed` | Ticket Created, Updated, Status Changed | Ticket change signal |
| `zendesk.ticket.comment.changed` | Comment Created | Comment change signal |

### Webhook Verification

Zendesk webhooks deliver signed JSON payloads. The signature is a
base64-encoded HMAC-SHA256 of the raw request body using the webhook's
shared secret.

```elixir
# Verify a webhook delivery
alias Jido.Connect.Zendesk.Webhook

# Compute the expected signature from the raw body and your secret
computed = Webhook.compute_signature(raw_body, shared_secret)

# Compare with the signature from the request header
case Webhook.verify_signature(computed, signature_header) do
  :ok ->
    # Normalize the verified event
    {:ok, signal} = Webhook.normalize_event(parsed_body)

  {:error, _reason} ->
    # Reject the delivery
    :invalid
end
```

### Supported Webhook Events

| Event Type | Description |
|---|---|
| `Ticket Created` | A new ticket was created |
| `Ticket Updated` | An existing ticket was updated |
| `Ticket Status Changed` | A ticket's status changed |
| `Comment Created` | A comment was added to a ticket |

### Signal Shape — Ticket Events

```elixir
%{
  event_type: "Ticket Updated",
  change_type: "updated",
  ticket_id: 12345,
  subject: "Cannot reset password",
  status: "solved",
  priority: "normal",
  tags: ["password", "resolved"],
  previous: %{status: "open", assignee_id: 9001},
  webhook_id: "wh-invocation-002",
  account_id: "example",
  timestamp: "2026-03-16T09:00:00Z"
}
```

### Signal Shape — Comment Events

```elixir
%{
  event_type: "Comment Created",
  change_type: "created",
  comment_id: 50001,
  comment_body: "Please check your spam folder.",
  comment_public: true,
  comment_author_id: 9001,
  ticket_id: 12345,
  ticket_subject: "Cannot reset password",
  webhook_id: "wh-invocation-003",
  account_id: "example",
  timestamp: "2026-03-15T11:00:00Z"
}
```

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:zendesk_reader` | read | Read-only Zendesk queries |
| `:zendesk_editor` | write | Reader + write tools |

Triggers are subscribed to independently and are not included in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("zendesk",
  modules: [Jido.Connect.Zendesk],
  packs: Jido.Connect.Zendesk.catalog_packs(),
  pack: :zendesk_reader
)

# Full editor access
Catalog.search_tools("zendesk",
  modules: [Jido.Connect.Zendesk],
  packs: Jido.Connect.Zendesk.catalog_packs(),
  pack: :zendesk_editor
)
```

## API Boundaries

All Zendesk API traffic uses
`Jido.Connect.Zendesk.Client.Transport.request/2`, which builds bearer
requests against the configurable Zendesk subdomain base URL.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, triggers, and catalog packs through injected fake
clients and does **not** call live Zendesk APIs.

### Environment Variables for Live Testing

```sh
export ZENDESK_SUBDOMAIN="your-subdomain"
export ZENDESK_EMAIL="your-email@example.com"
export ZENDESK_API_TOKEN="your-api-token"
# Optional: for webhook signature smoke tests
export ZENDESK_WEBHOOK_SECRET="your-webhook-secret"
# Optional: for get-ticket smoke test
export ZENDESK_TICKET_ID="12345"
# Never commit these values to version control.
```

### Running Live Smoke Tests

```sh
ZENDESK_SUBDOMAIN=example ZENDESK_API_TOKEN=xxx \
  mix test apps/jido_connect_zendesk/test --include live_smoke --no-deps-check
```

Live smoke tests are read-only — no tickets are created, updated, or deleted.

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Zendesk package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_zendesk
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_zendesk/test --no-deps-check
```
