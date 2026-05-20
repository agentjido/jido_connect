# Jido Connect Asana

`jido_connect_asana` is the Asana provider package for `jido_connect`.

It includes:

- `Jido.Connect.Asana`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:asana_reader`, `:asana_editor`)
- Webhook triggers for task and project events

The Spark DSL declaration lives in
`lib/jido_connect/asana.ex`.

## Status

This is an **experimental** package. Action fragments, normalized structs,
client transport, webhook triggers, and trigger handlers are implemented.

## Installation

```elixir
def deps do
  [
    {:jido_connect_asana, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Asana:

- **Personal access token** (`:pat`): Asana personal access token sent via the
  `Authorization: Bearer <token>` header. Created in the Asana developer
  console under "My app settings". Recommended for server-to-server
  integrations, development, and CI.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Asana authorization server. Grants scoped access on behalf of an Asana user.
  Public integrations use this flow to request access to specific workspaces
  and projects.

## Asana Scopes

The provider declares Asana permission scopes:

| Scope | Description |
|---|---|
| `default` | Basic read access to workspaces, projects, and tasks |
| `read` | Extended read access |
| `write` | Create and update tasks, projects, and sections |

`default` and `read` scopes are included in the default scope set for both
auth profiles. The `write` scope should be requested only when mutation actions
are needed.

### Scope Matrix

| Tool ID | Required Scopes |
|---|---|
| `asana.workspace.list` | `default` |
| `asana.project.list` | `default`, `read` |
| `asana.task.list` | `default`, `read` |
| `asana.task.get` | `default`, `read` |
| `asana.task.search` | `default`, `read` |
| `asana.story.list` | `default`, `read` |
| `asana.user.get` | `default`, `read` |
| `asana.user.list` | `default`, `read` |
| `asana.task.create` | `write` |
| `asana.task.update` | `write` |
| `asana.task.complete` | `write` |
| `asana.task.uncomplete` | `write` |
| `asana.task.add_project` | `write` |
| `asana.task.remove_project` | `write` |
| `asana.task.add_tag` | `write` |
| `asana.task.remove_tag` | `write` |
| `asana.story.create` | `write` |
| `asana.task.changed` | `default`, `read` |
| `asana.task.added` | `default`, `read` |
| `asana.task.deleted` | `default`, `read` |
| `asana.project.changed` | `default`, `read` |

## Actions

The provider declares 17 action tools across workspaces, projects, tasks,
stories, and users:

| Action ID | Verb | Effect | Description |
|---|---|---|---|
| `asana.workspace.list` | list | read | List workspaces |
| `asana.project.list` | list | read | List projects |
| `asana.task.list` | list | read | List tasks |
| `asana.task.get` | get | read | Get a task by GID |
| `asana.task.search` | search | read | Search tasks in a workspace |
| `asana.story.list` | list | read | List stories for a task |
| `asana.user.get` | get | read | Get a user by GID |
| `asana.user.list` | list | read | List users |
| `asana.task.create` | create | write | Create a new task |
| `asana.task.update` | update | write | Update a task |
| `asana.task.complete` | update | write | Mark a task complete |
| `asana.task.uncomplete` | update | write | Mark a task incomplete |
| `asana.task.add_project` | update | write | Add a task to a project |
| `asana.task.remove_project` | update | write | Remove a task from a project |
| `asana.task.add_tag` | update | write | Add a tag to a task |
| `asana.task.remove_tag` | update | write | Remove a tag from a task |
| `asana.story.create` | create | write | Add a comment to a task |

## Webhook Triggers

The provider ships with webhook triggers for task and project events:

### Task Triggers

| Trigger ID | Action | Description |
|---|---|---|
| `asana.task.changed` | `changed` | Task was updated |
| `asana.task.added` | `added` | Task was created |
| `asana.task.deleted` | `deleted` | Task was deleted |

### Project Triggers

| Trigger ID | Action | Description |
|---|---|---|
| `asana.project.changed` | `changed` | Project was updated |

### Webhook Verification

Asana signs webhook payloads with an HMAC-SHA256 hex digest sent in the
`X-Hook-Signature` header. The `Jido.Connect.Asana.Webhook` module provides
pure helpers for verification and normalization:

```elixir
alias Jido.Connect.Asana.Webhook

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
| `:asana_reader` | read | Read-only queries |
| `:asana_editor` | write | Reader + write tools |

Triggers are subscribed to independently and are not included in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("asana",
  modules: [Jido.Connect.Asana],
  packs: Jido.Connect.Asana.catalog_packs(),
  pack: :asana_reader
)

# Full editor access
Catalog.search_tools("asana",
  modules: [Jido.Connect.Asana],
  packs: Jido.Connect.Asana.catalog_packs(),
  pack: :asana_editor
)
```

## API Boundaries

All Asana API traffic uses the dedicated transport boundary module
`Jido.Connect.Asana.Client.Transport`. The base URL defaults to
`https://app.asana.com/api/1.0`.

## Environment Variables

| Variable | Description |
|---|---|
| `ASANA_ACCESS_TOKEN` | Personal access token for live smoke tests |
| `ASANA_WEBHOOK_SECRET` | Webhook shared secret for live signature tests |
| `ASANA_WORKSPACE_GID` | Workspace GID fixture for live smoke tests |
| `ASANA_PROJECT_GID` | Project GID fixture for live smoke tests |
| `ASANA_TASK_GID` | Task GID fixture for live smoke tests |

## Live Smoke Tests

Env-gated read-only live smoke hooks exercise real Asana API calls when
credentials are available:

```sh
ASANA_ACCESS_TOKEN=xxx mix test test/jido_connect/asana/live_smoke_test.exs --include live_smoke
```

All smoke tests are read-only — no tasks, projects, or stories are created,
updated, or deleted.

## Package Quality Gates

The Asana package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_asana
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_asana/test --no-deps-check
```
