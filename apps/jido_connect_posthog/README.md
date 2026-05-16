# Jido Connect PostHog

`jido_connect_posthog` is the PostHog analytics provider package for `jido_connect`.

It includes:

- `Jido.Connect.PostHog`, a Spark-authored provider that compiles into Jido tools
- PostHog event actions (list events, get event, capture event, batch capture events)
- PostHog person actions (list persons, get person)
- PostHog insight actions (list insights, get insight)
- PostHog query action (run HogQL queries)
- PostHog feature flag actions (evaluate flag, list flags, get flag)
- Scope resolver in `Jido.Connect.PostHog.ScopeResolver`
- Catalog packs for scoped tool discovery (`:posthog_reader`, `:posthog_writer`)
- REST client helpers in `Jido.Connect.PostHog.Client`
- REST transport boundary in `Jido.Connect.PostHog.Client.Transport`
- Response normalization in `Jido.Connect.PostHog.Client.Normalizer`

The Spark DSL declaration lives in
`lib/jido_connect/posthog.ex`. Provider handlers live under
`lib/jido_connect/posthog/handlers/`.

## Status

This is an **experimental** scaffold. Additional trigger fragments, webhook
support, and normalized structs may be added in subsequent waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_posthog, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles:

- **Project API key** (`:project_api_key`): PostHog project API key sent as a
  Bearer token. Suitable for read-only queries and event capture within a
  single project. This is the default profile.

- **Personal API key** (`:personal_api_key`): PostHog personal API key sent as
  a Bearer token. Grants access across projects and supports full scope
  coverage including feature flags and write operations. Recommended for
  server-to-server integrations and CI.

## Host Override

The transport boundary reads `posthog_api_base_url` from application env,
defaulting to `https://app.posthog.com`. Self-hosted PostHog deployments
override this at runtime or via config:

```elixir
config :jido_connect_posthog, posthog_api_base_url: "https://posthog.example.com"
```

## PostHog Scopes

| Scope | Description |
|---|---|
| `events:read` | Read captured events |
| `events:write` | Ingest events |
| `persons:read` | Read person profiles |
| `persons:write` | Update person profiles |
| `insights:read` | Read saved insights and run queries |
| `feature_flags:read` | Read and evaluate feature flags |
| `feature_flags:write` | Manage feature flags |

## Scope / Policy Matrix

| Action ID | Required Scopes | Risk | Available to Project API Key |
|---|---|---|---|
| `posthog.event.list` | `events:read` | read | yes |
| `posthog.event.get` | `events:read` | read | yes |
| `posthog.event.capture` | `events:write` | write | yes |
| `posthog.event.batch_capture` | `events:write` | write | yes |
| `posthog.person.list` | `persons:read` | read | yes |
| `posthog.person.get` | `persons:read` | read | yes |
| `posthog.insight.list` | `insights:read` | read | yes |
| `posthog.insight.get` | `insights:read` | read | yes |
| `posthog.query.run` | `insights:read` | read | yes |
| `posthog.feature_flag.evaluate` | `feature_flags:read` | read | no (personal API key only) |
| `posthog.feature_flag.list` | `feature_flags:read` | read | no (personal API key only) |
| `posthog.feature_flag.get` | `feature_flags:read` | read | no (personal API key only) |

> **Note:** Feature flag actions require the `:personal_api_key` profile because
> `feature_flags:read` is not included in the `:project_api_key` scope set.
> Event capture actions require `events:write`, which is available through
> the project API key but is not a default scope—connections must explicitly
> request it.

## Actions

### Event Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.event.list` | list | read | List captured events |
| `posthog.event.get` | get | read | Fetch a single event by UUID |
| `posthog.event.capture` | create | write | Capture a single event |
| `posthog.event.batch_capture` | create | write | Capture a batch of events |

### Person Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.person.list` | list | read | List persons |
| `posthog.person.get` | get | read | Fetch a person by distinct ID |

### Insight Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.insight.list` | list | read | List saved insights |
| `posthog.insight.get` | get | read | Fetch a single insight by short ID |

### Query Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.query.run` | create | read | Execute a HogQL query with optional date range |

### Feature Flag Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.feature_flag.evaluate` | get | read | Evaluate a flag for a distinct ID |
| `posthog.feature_flag.list` | list | read | List feature flags in the project |
| `posthog.feature_flag.get` | get | read | Fetch a single feature flag by ID |

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:posthog_reader` | read | Event, person, insight, query, and feature flag reads |
| `:posthog_writer` | write | Event capture and batch capture |

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools (analytics reader)
Catalog.search_tools("posthog",
  modules: [Jido.Connect.PostHog],
  packs: Jido.Connect.PostHog.catalog_packs(),
  pack: :posthog_reader
)

# Only expose event capture tools (event writer)
Catalog.search_tools("posthog",
  modules: [Jido.Connect.PostHog],
  packs: Jido.Connect.PostHog.catalog_packs(),
  pack: :posthog_writer
)
```

### Combining Packs

For a surface that needs both read and write access, pass all packs without
a `:pack` filter and let the caller manage scope at the connection level:

```elixir
# Full access — scope is governed by the connection's granted scopes
Catalog.search_tools("posthog",
  modules: [Jido.Connect.PostHog],
  packs: Jido.Connect.PostHog.catalog_packs()
)
```

## API Boundaries

All PostHog API traffic uses REST through
`Jido.Connect.PostHog.Client.Transport`, which builds bearer
requests against the PostHog API endpoint.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, scope resolution, catalog packs, tool availability,
and action handlers through injected fake clients and does **not** call live
PostHog APIs.

### Environment Variables for Live Testing

```sh
export POSTHOG_API_KEY="your-api-key-here"
# Never commit these values to version control.
```

For feature flag access, use a personal API key:

```sh
export POSTHOG_PERSONAL_API_KEY="your-personal-api-key-here"
```

### Live API Testing

To verify actions against a real PostHog instance:

1. Create a PostHog project at `https://app.posthog.com` (or your self-hosted
   instance).
2. Generate a project API key from **Settings → Project API Keys**.
3. Generate a personal API key from **Settings → Personal API Keys** (required
   for feature flag actions).
4. Set the environment variables above.
5. Run the test suite with live credentials only in isolated, non-CI
   environments.

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

### Scope Verification

Use the scope resolver to verify required scopes for each action:

```elixir
# Check what scopes an action needs
Jido.Connect.PostHog.ScopeResolver.required_scopes(
  %{id: "posthog.event.capture"}, %{}, %{}
)
# => ["events:write"]
```

### Tool Availability

The plugin module reports tool availability based on connection state:

```elixir
# Without a connection — all tools report :connection_required
Jido.Connect.PostHog.Plugin.tool_availability()

# With a connection — tools report :available or :connection_required
# depending on granted scopes
Jido.Connect.PostHog.Plugin.tool_availability(%{connection: conn})
```

## Package Quality Gates

The PostHog package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_posthog
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_posthog/test --no-deps-check
```
