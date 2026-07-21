# Jido Connect Notion

`jido_connect_notion` is the Notion provider package for `jido_connect`.

It includes:

- `Jido.Connect.Notion`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:notion_reader`, `:notion_editor`)

The Spark DSL declaration lives in
`lib/jido_connect/notion.ex`.

## Status

This is an **experimental** package. Action fragments, normalized structs,
client transport, and action handlers are implemented.

## Installation

```elixir
def deps do
  [
    {:jido_connect_notion, "~> 0.8"}
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

The provider declares 13 action tools across search, pages, databases, blocks,
and comments:

### Read Actions

| Action ID | Verb | Description |
|---|---|---|
| `notion.search` | list | Search pages and databases in a workspace |
| `notion.page.get` | get | Retrieve a page by ID |
| `notion.database.get` | get | Retrieve a database by ID |
| `notion.database.query` | list | Query a database with filters and sorts |
| `notion.block.get` | get | Retrieve a block by ID |
| `notion.block.list_children` | list | List child blocks of a block or page |
| `notion.comment.list` | list | List comments on a block or page |

### Write Actions

| Action ID | Verb | Effect | Description |
|---|---|---|---|
| `notion.page.create` | create | write | Create a new page |
| `notion.page.update` | update | write | Update page properties or archive status |
| `notion.block.append_children` | update | write | Append child blocks to a block or page |
| `notion.block.update` | update | write | Update block content or archived status |
| `notion.block.archive` | update | destructive | Archive (soft-delete) a block |
| `notion.comment.create` | create | write | Create a comment on a page |

## Webhook Triggers

Notion does **not** provide broad generic webhooks for resource changes. There
is no push-based notification mechanism that covers all resources in a
workspace. See [Change Detection Strategy](#change-detection-strategy) below.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:notion_reader` | read | 7 read-only Notion queries |
| `:notion_editor` | write | Reader + 6 write tools |

Tool IDs are populated from action fragments.

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

## Change Detection Strategy

Notion lacks a general-purpose webhook subscription mechanism. To detect
changes to pages, databases, and blocks, use polling:

1. **Checkpoint store**: Persist the last-seen `last_edited_time` after each
   poll cycle.
2. **Incremental query**: Use `notion.database.query` or `notion.search` with
   a filter for `last_edited_time > checkpoint` and sort ascending.
3. **Backfill**: On first run or after a gap, perform a full scan and record
   the latest timestamp as the new checkpoint.
4. **Poll interval**: Balance freshness against API rate limits. Notion
   recommends staying within 3 requests per second for integration tokens.

See `docs/notion_scope_matrix.md` for the full scope/capability matrix and
least-privilege guidance.

## API Boundaries

All Notion API traffic uses the dedicated transport boundary module
`Jido.Connect.Notion.Client.Transport`. The base URL defaults to
`https://api.notion.com/v1`.

## Environment Variables

| Variable | Description |
|---|---|
| `NOTION_TOKEN` | Internal integration token for live smoke tests |
| `NOTION_PAGE_ID` | Page ID fixture for live smoke read tests |
| `NOTION_DATABASE_ID` | Database ID fixture for live smoke read tests |

See the root `.env.example` for placeholder entries.

## Live Smoke Tests

The package includes env-gated read-only live smoke tests that exercise real
Notion API calls without mutation. These tests only run when `NOTION_TOKEN` is
set and `--include live_smoke` is passed:

```sh
NOTION_TOKEN=xxx mix test test/jido_connect/notion/live_smoke_test.exs --include live_smoke
```

All smoke tests are read-only — no pages, blocks, or comments are created,
updated, or deleted.

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
