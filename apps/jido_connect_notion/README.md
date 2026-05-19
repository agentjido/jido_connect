# Jido Connect Notion

`jido_connect_notion` is the Notion provider package for `jido_connect`.

It includes:

- `Jido.Connect.Notion`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:notion_reader`, `:notion_editor`)

The Spark DSL declaration lives in
`lib/jido_connect/notion.ex`.

## Status

This is an **experimental** package. Action fragments, normalized structs,
client transport, and webhook handlers will be added in subsequent waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_notion, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Notion:

- **Internal integration token** (`:internal_token`): Notion internal
  integration token sent via the `Authorization: Bearer <token>` header.
  Created in the Notion workspace integrations settings. Recommended for
  server-to-server integrations, development, and CI. Internal integration
  tokens have access to all pages and databases the integration has been
  explicitly granted access to.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Notion authorization server. Grants scoped access on behalf of a Notion
  workspace user. Public integrations use this flow to request access to
  specific capabilities within a user's workspace.

## Notion Scopes

The provider declares Notion permission scopes:

| Scope | Description |
|---|---|
| `read_content` | Read pages and blocks |
| `insert_content` | Create pages and blocks |
| `update_content` | Update pages and blocks |
| `read_comments` | Read comments on pages |
| `insert_comments` | Create comments on pages |
| `read_databases` | Read databases |
| `insert_databases` | Create databases |
| `update_databases` | Update databases |
| `read_users` | Read workspace users |

Read scopes are included in the default scope set for the internal integration
token profile. Write scopes should be requested only when mutation actions
are needed.

## Actions

> Action fragments will be added in a subsequent wave.

## Webhook Triggers

> Webhook trigger fragments will be added in a subsequent wave.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:notion_reader` | read | Read-only Notion queries |
| `:notion_editor` | write | Reader + write tools |

Tool IDs will be populated when action fragments are added in subsequent waves.

Triggers are subscribed to independently and are not included in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("notion",
  modules: [Jido.Connect.Notion],
  packs: Jido.Connect.Notion.catalog_packs(),
  pack: :notion_reader
)

# Full editor access
Catalog.search_tools("notion",
  modules: [Jido.Connect.Notion],
  packs: Jido.Connect.Notion.catalog_packs(),
  pack: :notion_editor
)
```

## API Boundaries

All Notion API traffic will use a dedicated transport boundary module to be
added in a subsequent wave. The base URL defaults to
`https://api.notion.com/v1`.

## Package Quality Gates

The Notion package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_notion
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_notion/test --no-deps-check
```
