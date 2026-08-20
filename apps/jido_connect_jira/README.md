# Jido Connect Jira

`jido_connect_jira` is the Jira provider package for `jido_connect`.

It includes:

- `Jido.Connect.Jira`, a Spark-authored provider that compiles into Jido tools
- Jira issue actions, including transition discovery and destructive issue deletion
- Jira project and metadata actions (list projects, get project, list field schemas)
- Jira Software board actions and Jira saved-filter actions
- Privileged Jira plan administration actions
- Webhook triggers for issue created/updated and comment created/updated events
- Webhook verification and normalization in `Jido.Connect.Jira.Webhook`
- Catalog packs for ordinary, privileged, and destructive tool discovery
- OAuth2 helpers in `Jido.Connect.Jira.OAuth`
- REST client helpers in `Jido.Connect.Jira.Client`
- Transport boundary in `Jido.Connect.Jira.Client.Transport`
- Response normalization in `Jido.Connect.Jira.Client.Normalizer`

The Spark DSL declaration lives in
`lib/jido_connect/jira.ex`. Provider handlers live under
`lib/jido_connect/jira/handlers/`.

## Status

This package is **experimental**. Its 29 actions use fixed Jira Cloud REST
contracts, normalized results, and bounded inputs.

## Installation

```elixir
def deps do
  [
    {:jido_connect_jira, "~> 0.8"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Atlassian Cloud:

- **API token** (`:api_token`): Atlassian account email and API token sent
  with HTTP Basic authentication.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
  with PKCE against the Atlassian authorization server. Grants scoped
  access on behalf of an Atlassian user.

## Atlassian Cloud Scopes

The provider declares Atlassian Cloud scopes for Jira:

| Scope | Description |
|---|---|
| `read:jira-work` | Read Jira work data |
| `write:jira-work` | Change Jira work data |
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
| `jira.issue.transition.list` | list | read | List available issue transitions |
| `jira.issue.delete` | delete | destructive | Permanently delete an issue |
| `jira.issue.assign` | update | write | Assign issue to user |
| `jira.issue.comment.create` | create | external_write | Add comment to issue |

### Project and Metadata Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.project.list` | list | read | List visible projects |
| `jira.project.get` | get | read | Get project by key |
| `jira.field_schema.list` | list | read | List field schemas |

### Board Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.board.list` | list | read | List visible Jira Software boards |
| `jira.board.get` | get | read | Get one board |
| `jira.board.create` | create | write | Create a filter-backed board |

### Filter Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.filter.list` | list | read | List saved filters |
| `jira.filter.get` | get | read | Get one saved filter |
| `jira.filter.create` | create | write | Create a saved filter |
| `jira.filter.update` | update | write | Update a saved filter |
| `jira.filter.columns.get` | get | read | Get saved-filter columns |
| `jira.filter.columns.update` | update | write | Replace saved-filter columns |
| `jira.filter.share.update` | update | external_write | Replace all filter share permissions |

Filter share replacement can send more than one request. The client disables
automatic retries for the complete operation. If a write can have reached
Jira, the returned provider error reports uncertain delivery and does not
recommend a retry.

### Plan Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `jira.plan.list` | list | read | List plans with cursor paging |
| `jira.plan.get` | get | read | Get one plan |
| `jira.plan.create` | create | write | Create a plan |
| `jira.plan.update` | update | write | Update a plan with JSON Patch |
| `jira.plan.duplicate` | create | write | Duplicate a plan |
| `jira.plan.archive` | archive | destructive | Archive a plan |
| `jira.plan.trash` | delete | destructive | Move a plan to trash |

Every plan action requires the `:jira_admin_access` host policy. Issue delete,
plan archive, and plan trash always require confirmation.

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
| `:jira_reader` | Ordinary issue, project, board, filter, transition, and field schema reads |
| `:jira_editor` | Reader + non-destructive issue, board, and filter writes |
| `:jira_admin` | Non-destructive plan reads and writes; host policy is still required |
| `:jira_destructive` | Issue delete, plan archive, and plan trash |

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

# Privileged plan tools
Catalog.search_tools("jira",
  modules: [Jido.Connect.Jira],
  packs: Jido.Connect.Jira.catalog_packs(),
  pack: :jira_admin
)
```

## API Boundaries

All Jira API traffic uses a `Jido.Connect.Jira.Client.Request`. The request
contains the selected `Jido.Connect.Connection`, its auth profile, its
connection-specific endpoint, and the leased credential fields. API-token
connections read `:site` from connection metadata. OAuth connections can use a
`:cloud_endpoint`, such as the Atlassian API gateway URL for one cloud ID. Jira
connection endpoints must use HTTPS. Tests should use a Req transport plug with
an HTTPS endpoint instead of a plaintext credential endpoint.

Hosts inject a test or custom client with the runtime `:provider_client` option.
The client module is infrastructure. Do not put it in credential fields.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, webhook normalization, and catalog packs through
injected fake clients and does **not** call live Jira APIs.

### Environment Variables for Live Testing

```sh
export JIRA_API_TOKEN="your-api-token-here"
export JIRA_EMAIL="you@example.com"
export JIRA_SITE="https://your-domain.atlassian.net"
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

The connector reads the selected site from connection metadata and reads the
email and API token from the credential lease. OAuth leases use
`:access_token`. No process-global Jira endpoint is used.

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
