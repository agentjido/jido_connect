# Jido Connect Intercom

`jido_connect_intercom` is the Intercom provider package for `jido_connect`.

It includes:

- `Jido.Connect.Intercom`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:intercom_reader`, `:intercom_editor`)

The Spark DSL declaration lives in
`lib/jido_connect/intercom.ex`.

## Status

This is an **experimental** package. Action fragments, normalized structs,
client transport, and webhook handlers will be added in subsequent waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_intercom, "~> 0.1.0"}
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

> Action fragments will be added in a subsequent wave.

## Webhook Triggers

> Webhook trigger fragments will be added in a subsequent wave.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:intercom_reader` | read | Read-only Intercom queries |
| `:intercom_editor` | write | Reader + write tools |

Tool IDs will be populated when action fragments are added in subsequent waves.

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

All Intercom API traffic will use a dedicated transport boundary module to be
added in a subsequent wave. The base URL defaults to
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
