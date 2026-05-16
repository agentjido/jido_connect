# Jido Connect Jira

`jido_connect_jira` is the Jira provider package for `jido_connect`.

It includes:

- `Jido.Connect.Jira`, a Spark-authored provider that compiles into Jido tools
- Jira issue actions (get, search, create, update, transition, assign, comment)
- Jira project and metadata actions (list projects, get project, list field schemas)
- Webhook triggers for issue created/updated and comment created/updated events
- Webhook verification and normalization in `Jido.Connect.Jira.Webhook`
- Catalog packs for scoped tool discovery (`:jira_reader`, `:jira_editor`)
- OAuth2 helpers in `Jido.Connect.Jira.OAuth`
- REST client helpers in `Jido.Connect.Jira.Client`
- Transport boundary in `Jido.Connect.Jira.Client.Transport`
- Response normalization in `Jido.Connect.Jira.Client.Normalizer`

The Spark DSL declaration lives in
`lib/jido_connect/jira.ex`. Provider handlers live under
`lib/jido_connect/jira/handlers/`.

## Status

This is an **experimental** scaffold. Additional action fragments, trigger
fragments, normalized structs, and webhook support will be added in subsequent
waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_jira, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Atlassian Cloud:

- **API token** (`:api_token`): Jira personal access token or Atlassian
  API token passed as a Bearer token. Recommended for server-to-server
  integrations, development, and CI.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
  with PKCE against the Atlassian authorization server. Grants scoped
  access on behalf of an Atlassian user.

## Atlassian Cloud Scopes

The provider declares Atlassian Cloud scopes for Jira:

| Scope | Description |
|---|---|
| `read:jira-work` | Read issues, projects, and filters |
| `write:jira-work` | Create and update issues |
| `read:jira-users` | Read user information |
| `read:jira-configuration` | Read project and configuration data |

Read scopes are included in both default scope sets. The `write:jira-work`
scope is optional for the OAuth2 profile and should be requested only when
mutation actions are needed.

## Actions

### Issue Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.issue.get` | get | read | Fetch an issue by key |
| `jira.issue.search` | search | read | Search issues with JQL |
| `jira.issue.create` | create | write | Create a new issue |
| `jira.issue.update` | update | write | Update issue fields |
| `jira.issue.transition` | update | write | Transition issue status |
| `jira.issue.assign` | update | write | Assign issue to user |
| `jira.issue.comment.create` | create | external_write | Add comment to issue |

### Project and Metadata Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.project.list` | list | read | List visible projects |
| `jira.project.get` | get | read | Get project by key |
| `jira.field_schema.list` | list | read | List field schemas |

## Webhook Triggers

The provider declares webhook triggers for real-time issue and comment events:

| Trigger ID | Resource | Events |
|---|---|---|
| `jira.issue.changed` | issue | `jira:issue_created`, `jira:issue_updated` |
| `jira.comment.changed` | comment | `comment_created`, `comment_updated` |

### Webhook Verification

`Jido.Connect.Jira.Webhook` provides pure helpers for:

- **Signature verification**: HMAC-SHA256 base64 of the raw body against the
  webhook shared secret. Use `compute_signature/2` to compute the digest and
  `verify_signature/2` for constant-time comparison.
- **Event normalization**: `normalize_event/1` converts a raw Jira webhook
  payload into a flat signal map with stable field names. Issue events include
  changelog details; comment events include issue context.
- **Batch normalization**: `normalize_events/1` processes a list of events.

### Webhook Event Fields

Issue events produce signals with:

- `event_type`, `change_type` (`"created"` or `"updated"`)
- `issue_id`, `issue_key`, `project_key`, `summary`, `status_name`
- `assignee_id`, `assignee_name`, `reporter_id`, `reporter_name`
- `labels`, `issue_type_name`, `priority_name`
- `changelog` (updated events only, with field-level change items)
- `webhook_id`, `timestamp`

Comment events produce signals with:

- `event_type`, `change_type` (`"created"` or `"updated"`)
- `comment_id`, `comment_body`, `comment_author_id`, `comment_author_name`
- `comment_created_at`, `comment_updated_at`
- `issue_id`, `issue_key` (context)
- `webhook_id`, `timestamp`

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:jira_reader` | Issue get/search, project list/get, field schema list |
| `:jira_editor` | Reader + issue create/update/transition/assign/comment |

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("jira",
  modules: [Jido.Connect.Jira],
  packs: Jido.Connect.Jira.catalog_packs(),
  pack: :jira_reader
)

# Full editor access
Catalog.search_tools("jira",
  modules: [Jido.Connect.Jira],
  packs: Jido.Connect.Jira.catalog_packs(),
  pack: :jira_editor
)
```

## API Boundaries

All Jira API traffic uses
`Jido.Connect.Jira.Client.Transport.request/2`, which builds bearer
requests against the configurable Atlassian Cloud base URL.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, webhook normalization, and catalog packs through
injected fake clients and does **not** call live Jira APIs.

### Environment Variables for Live Testing

```sh
export JIRA_API_TOKEN="your-api-token-here"
export JIRA_API_BASE_URL="https://your-domain.atlassian.net"
# Never commit these values to version control.
```

### Live Webhook Testing

To verify webhook delivery from a Jira Cloud instance:

1. Register a webhook in Jira pointing to your endpoint URL.
2. Configure the webhook shared secret for signature verification.
3. Use `Jido.Connect.Jira.Webhook.compute_signature/2` to compute the
   expected HMAC-SHA256 base64 digest.
4. Use `Jido.Connect.Jira.Webhook.verify_signature/2` to compare against
   the header value in constant time.
5. Use `Jido.Connect.Jira.Webhook.normalize_event/1` to normalize the
   accepted payload into a trigger signal.

Do not expose the webhook shared secret in logs or public payloads.

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Jira package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_jira
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_jira/test --no-deps-check
```
