# Jido Connect PostHog

`jido_connect_posthog` is the PostHog analytics provider package for `jido_connect`.

It includes:

- `Jido.Connect.PostHog`, a Spark-authored provider that compiles into Jido tools
- PostHog event actions (list events, get event)
- PostHog person actions (list persons, get person)
- PostHog insight actions (list insights, get insight)
- Catalog packs for scoped tool discovery (`:posthog_reader`)
- REST client helpers in `Jido.Connect.PostHog.Client`
- REST transport boundary in `Jido.Connect.PostHog.Client.Transport`

The Spark DSL declaration lives in
`lib/jido_connect/posthog.ex`. Provider handlers live under
`lib/jido_connect/posthog/handlers/`.

## Status

This is an **experimental** scaffold. Additional action fragments, trigger
fragments, normalized structs, and feature flag support will be added in
subsequent waves.

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

- **Project API key** (`:project_api_key`): PostHog project API key passed as
  a Bearer token. Suitable for read-only queries and event capture within a
  single project.

- **Personal API key** (`:personal_api_key`): PostHog personal API key passed
  as a Bearer token. Grants access across projects and supports write
  operations. Recommended for server-to-server integrations and CI.

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
| `insights:read` | Read saved insights |
| `feature_flags:read` | Read feature flags |
| `feature_flags:write` | Manage feature flags |

## Actions

### Event Actions

| Action ID | Verb | Risk | Description |
|---|---|---|---|
| `posthog.event.list` | list | read | List captured events |
| `posthog.event.get` | get | read | Fetch a single event by UUID |

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

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:posthog_reader` | All event, person, and insight read actions |

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("posthog",
  modules: [Jido.Connect.PostHog],
  packs: Jido.Connect.PostHog.catalog_packs(),
  pack: :posthog_reader
)
```

## API Boundaries

All PostHog API traffic uses REST through
`Jido.Connect.PostHog.Client.Transport`, which builds bearer
requests against the PostHog API endpoint.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, and catalog packs through injected fake
clients and does **not** call live PostHog APIs.

### Environment Variables for Live Testing

```sh
export POSTHOG_API_KEY="your-api-key-here"
# Never commit these values to version control.
```

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

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
