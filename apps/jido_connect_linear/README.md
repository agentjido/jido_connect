# Jido Connect Linear

`jido_connect_linear` is the Linear provider package for `jido_connect`.

It includes:

- `Jido.Connect.Linear`, a Spark-authored provider that compiles into Jido tools
- Linear issue actions (get, search, create, update, add comment)
- Linear team actions (list teams)
- Webhook triggers for issue created, updated, and removed events, and comment created and updated events
- Webhook verification and normalization in `Jido.Connect.Linear.Webhook`
- Catalog packs for scoped tool discovery (`:linear_reader`, `:linear_editor`)
- OAuth2 helpers in `Jido.Connect.Linear.OAuth`
- GraphQL client helpers in `Jido.Connect.Linear.Client`
- GraphQL transport boundary in `Jido.Connect.Linear.Client.Transport`
- Response normalization in `Jido.Connect.Linear.Client.Response`

The Spark DSL declaration lives in
`lib/jido_connect/linear.ex`. Provider handlers live under
`lib/jido_connect/linear/handlers/`.

## Status

This is an **experimental** scaffold. Additional action fragments, trigger
fragments, normalized structs, and webhook support will be added in subsequent
waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_linear, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles:

- **API key** (`:api_key`): Linear personal access token passed as a Bearer
  token. Recommended for server-to-server integrations, development, and CI.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
  with PKCE against the Linear authorization server. Grants scoped
  access on behalf of a Linear user.

## Linear Scopes

| Scope | Description |
|---|---|
| `read` | Read issues, teams, and projects |
| `write` | Create and update issues |
| `issues:create` | Create new issues |
| `comments:create` | Create comments on issues |

The `read` scope is the default for both profiles. Write scopes are optional
for the OAuth2 profile and should be requested only when mutation actions
are needed.

## Actions

### Issue Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `linear.issue.get` | get | read | Fetch an issue by ID |
| `linear.issue.search` | search | read | Search issues with filter |
| `linear.issue.create` | create | write | Create a new issue |
| `linear.issue.update` | update | write | Update issue fields |
| `linear.issue.comment.create` | create | external_write | Add comment to issue |

### Team Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `linear.team.list` | list | read | List visible teams |

## Webhook Triggers

The provider declares webhook triggers for real-time issue and comment events:

| Trigger ID | Resource | Events |
|---|---|---|
| `linear.issue.changed` | issue | `create`, `update`, `remove` |
| `linear.comment.changed` | comment | `create`, `update` |

### Webhook Verification

`Jido.Connect.Linear.Webhook` provides pure helpers for:

- **Signature verification**: HMAC-SHA256 base64 of the raw body against the
  webhook signing secret. The signature is sent in the `linear-signature`
  header. Use `compute_signature/2` to compute the digest and
  `verify_signature/2` for constant-time comparison.
- **Event normalization**: `normalize_event/1` converts a raw Linear webhook
  payload (Issue or Comment type) into a flat signal map with stable field names.
- **Batch normalization**: `normalize_events/1` processes a list of events.

### Webhook Event Fields

Issue events produce signals with:

- `event_type` (`"Issue"`), `action` (`"create"`, `"update"`, or `"remove"`)
- `issue_id`, `identifier`, `team_id`, `team_key`, `title`
- `status_name`, `priority_label`
- `assignee_id`, `assignee_name`, `creator_id`, `creator_name`
- `labels`
- `created_at`, `updated_at`
- `webhook_id`, `timestamp`

Comment events produce signals with:

- `event_type` (`"Comment"`), `action` (`"create"` or `"update"`)
- `comment_id`, `comment_body`
- `issue_id`, `issue_identifier`
- `user_id`, `user_name`
- `created_at`, `updated_at`
- `webhook_id`, `timestamp`

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:linear_reader` | Issue get/search, team list |
| `:linear_editor` | Reader + issue create/update/comment |

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("linear",
  modules: [Jido.Connect.Linear],
  packs: Jido.Connect.Linear.catalog_packs(),
  pack: :linear_reader
)

# Full editor access
Catalog.search_tools("linear",
  modules: [Jido.Connect.Linear],
  packs: Jido.Connect.Linear.catalog_packs(),
  pack: :linear_editor
)
```

## API Boundaries

All Linear API traffic uses GraphQL through
`Jido.Connect.Linear.Client.Transport`, which builds bearer
requests against the Linear GraphQL endpoint at
`https://api.linear.app/graphql`.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, webhook normalization, and catalog packs through
injected fake clients and does **not** call live Linear APIs.

### Environment Variables for Live Testing

```sh
export LINEAR_API_KEY="your-api-key-here"
# Never commit these values to version control.
```

### Live Webhook Testing

To verify webhook delivery from a Linear workspace:

1. Register a webhook in Linear pointing to your endpoint URL.
2. Configure the webhook signing secret for signature verification.
3. Use `Jido.Connect.Linear.Webhook.compute_signature/2` to compute the
   expected HMAC-SHA256 base64 digest.
4. Use `Jido.Connect.Linear.Webhook.verify_signature/2` to compare against
   the header value in constant time.
5. Use `Jido.Connect.Linear.Webhook.normalize_event/1` to normalize the
   accepted payload into a trigger signal.

Do not expose the webhook signing secret in logs or public payloads.

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Linear package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_linear
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_linear/test --no-deps-check
```
