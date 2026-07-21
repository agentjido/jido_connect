# Notion Scope Matrix

The Notion connector treats OAuth and internal integration token scope coverage
as action metadata, resolved at runtime by
`Jido.Connect.Notion.ScopeResolver`.

## Scope Resolution

Every action declares:

- Static `scopes` metadata in its DSL `access` block — the least-privilege
  scope advertised through the action catalog.
- A provider-local `scope_resolver` for runtime scope satisfaction checks.
- Auth profile coverage — every scope must be listed in the provider's
  `default_scopes` or `optional_scopes`.

## Scope Inventory

| Scope | Auth Profile | Default | Description |
|---|---|:---:|---|
| `read_content` | Internal token, OAuth2 | ✓ | Read pages and blocks |
| `insert_content` | Internal token, OAuth2 | ✗ | Create pages and blocks |
| `update_content` | Internal token, OAuth2 | ✗ | Update pages and blocks |
| `read_comments` | Internal token, OAuth2 | ✓ | Read comments on pages |
| `insert_comments` | Internal token, OAuth2 | ✗ | Create comments on pages |
| `read_databases` | Internal token, OAuth2 | ✓ | Read databases |
| `insert_databases` | Internal token, OAuth2 | ✗ | Create databases |
| `update_databases` | Internal token, OAuth2 | ✗ | Update databases |
| `read_users` | Internal token, OAuth2 | ✓ | Read workspace users |

## Action → Scope Mapping

### Read Actions

| Action ID | Effect | Required Scopes |
|---|---|---|
| `notion.search` | read | `read_content` |
| `notion.page.get` | read | `read_content` |
| `notion.database.get` | read | `read_content`, `read_databases` |
| `notion.database.query` | read | `read_content`, `read_databases` |
| `notion.block.get` | read | `read_content` |
| `notion.block.list_children` | read | `read_content` |
| `notion.comment.list` | read | `read_comments` |

### Write Actions

| Action ID | Effect | Required Scopes |
|---|---|---|
| `notion.page.create` | write | `insert_content` |
| `notion.page.update` | write | `update_content` |
| `notion.block.append_children` | write | `insert_content` |
| `notion.block.update` | write | `update_content` |
| `notion.block.archive` | destructive | `update_content` |
| `notion.comment.create` | write | `insert_comments` |

## Capability Matrix

| Capability | Read Scope | Write Scope | Notes |
|---|---|---|---|
| Search | `read_content` | — | Search across pages and databases |
| Pages | `read_content` | `insert_content`, `update_content` | CRUD for pages |
| Databases | `read_content`, `read_databases` | `insert_databases`, `update_databases` | Query and manage databases |
| Blocks | `read_content` | `insert_content`, `update_content` | Block-level read, append, update, archive |
| Comments | `read_comments` | `insert_comments` | Discussion threads on pages |

## Least-Privilege Guidance

- **Read-only surfaces** (dashboards, monitoring): use the `:internal_token`
  profile with default scopes (`read_content`, `read_databases`, `read_users`)
  and the `:notion_reader` catalog pack.

- **Content authoring** (AI-assisted page creation): use the `:internal_token`
  profile with optional write scopes (`insert_content`, `update_content`) and
  the `:notion_editor` catalog pack. Request explicit confirmation for write
  actions.

- **Comment management**: requires `insert_comments` scope in addition to
  `read_comments`. Comment creation uses the `write` effect with confirmation
  required for AI-initiated operations.

## Change Detection Strategy

Notion does **not** provide broad generic webhooks for resource changes. There
is no equivalent to a "page.updated" or "database.changed" push event that
covers all resources in a workspace.

### Available Notification Mechanisms

- **Page-level notifications**: Notion's API supports subscribing to changes on
  individual pages via the `pages/{page_id}` endpoint, but this is not a
  webhook mechanism — it requires polling.

- **Database query polling**: Use `notion.database.query` with `sort` by
  `last_edited_time` and a known checkpoint timestamp to detect changed pages
  within a database.

- **Search polling**: Use `notion.search` with a `sort` on `last_edited_time`
  to discover recently changed pages and databases across the workspace.

### Recommended Polling Pattern

1. **Checkpoint store**: Persist the last-seen `last_edited_time` after each
   poll cycle.
2. **Incremental query**: Use `notion.database.query` or `notion.search` with
   a filter for `last_edited_time > checkpoint` and sort ascending.
3. **Backfill**: On first run or after a gap, perform a full scan and record
   the latest timestamp as the new checkpoint.
4. **Poll interval**: Balance freshness against API rate limits. Notion
   recommends staying within 3 requests per second for integration tokens.

### Why No Webhook Triggers

The Notion connector does not declare webhook trigger fragments because
Notion's API does not expose a general-purpose webhook subscription mechanism
for resource changes. If Notion adds webhook support in the future, trigger
fragments can be added in a subsequent wave following the established trigger
DSL patterns.
