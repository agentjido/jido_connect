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

This package is **experimental**. Its 30 actions use fixed Jira Cloud REST
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
| `jira.issue.get` | get | read | Fetch an issue by key or numeric ID |
| `jira.issue.search` | search | read | Search issues with JQL, one page per call |
| `jira.issue.create` | create | write | Create a new issue |
| `jira.issue.update` | update | write | Update issue fields |
| `jira.issue.transition` | update | write | Transition issue status |
| `jira.issue.transition.list` | list | read | List available issue transitions |
| `jira.issue.delete` | delete | destructive | Permanently delete an issue |
| `jira.issue.assign` | update | write | Assign issue to user |
| `jira.issue.comment.create` | create | external_write | Add comment to issue |
| `jira.issue.comment.list` | list | read | List an issue's comments, one page per call |

### Issue Reads and Search

`jira.issue.get` calls `GET /rest/api/3/issue/{issueIdOrKey}`. The
`issue_key` input takes a key such as `PROJ-123` or a numeric issue ID such
as `10001`; the client sends it as one percent-encoded path segment. The
output carries `id`, `key`, `url` (the API `self` URL), `project`,
`assignee`, `status`, `priority`, `labels`, the plain-text `description` with
`description_unsupported_nodes`, the date-only `due_date` and the
timestamps. A field that Jira returns as `null` is absent from the output.
`missing_fields` lists the requested Jira field keys, such as `parent` on a
top-level issue or a field that the site's field configuration hides, that the
response does not contain at all, so an empty field and an unavailable one
stay apart.

Without `fields`, a read requests `*all`. The selectors `*all` and
`*navigable` count as the issue fields the connector reads: `summary`,
`description`, `status`, `issuetype`, `project`, `assignee`, `reporter`,
`priority`, `labels`, `components`, `fixVersions`, `duedate`, `resolution`,
`created`, `updated` and, for `*all` only, `timetracking`, which Jira does not
count as navigable. A list that only excludes fields, such as
`-description`, starts from `*all` for `jira.issue.get` and from `*navigable`
for `jira.issue.search`, as Jira does. Two limits remain: other fields that a
selector brings, such as custom fields, are not checked, and other selectors
starting with `*` are not resolved. Their absence never shows in
`missing_fields`.

`jira.issue.search` calls Jira's enhanced JQL search,
`POST /rest/api/3/search/jql`, with `jql`, `fields`, `maxResults` and
`nextPageToken`. The default fields are `summary`, `status`, `assignee`,
`updated`, `description`, `project` and `duedate`. A field list that names
only `id` is sent with `key` added, because Jira answers it with bare issue
IDs and each result carries its key. Each call returns one page with
`issues`, `next_page_token`, `is_last` and the page size sent as
`max_results`. Pass `next_page_token` to the next call until `is_last` is
`true`. Jira can return fewer issues than `max_results`, and a page can be
empty while `is_last` is `false`, so only `is_last` marks the end. A page
without an `issues` list or a boolean `isLast`, or a non-final page without a
token, fails with an `:invalid_response` error instead of ending the search.

Atlassian removed `POST /rest/api/3/search`, which now answers `410 Gone`, so
the action changed in place. Deprecated for one release and removed in the
next: the `start_at` input accepts only `0` and rejects any other value before
a request is sent, and the `total` and `start_at` outputs are declared but
never returned. Enhanced search has neither offsets nor a total.

### Issue Comments

`jira.issue.comment.list` calls `GET /rest/api/3/issue/{issueIdOrKey}/comment`
with `startAt`, `maxResults` and `orderBy=created`, so each page lists
comments oldest first. It does not request rendered HTML. The `issue_key`
input takes a key or a numeric issue ID, sent as one percent-encoded path
segment, and the output returns it unchanged as `issue`.

Each call returns one page with `comments`, `issue`, Jira's `start_at`,
`max_results` and `total`, `is_last` and `next_start_at`. Jira's comment page
has no last-page flag, so `is_last` is `true` once `start_at` plus the number
of comments reaches `total`. A page with fewer comments than `max_results` can
therefore be non-final. `next_start_at` is `start_at` plus the number of
comments and is absent on the last page; pass it as `start_at` until `is_last`
is `true`. A page at or past the end is empty and final. An empty page before
the end, and a page without a `comments` list or with a `startAt`,
`maxResults` or `total` that is not a non-negative integer, fail with an
`:invalid_response` error.

The page size is a connector choice: 50 by default, 1 to 100 allowed, where
Jira's own default is 100. `start_at` must not be negative. Other values fail
before a request is sent, because Jira would turn 0 into 1, cap larger sizes
at 100 and read a negative offset as 0.

Each comment carries `id`, `url` (the API `self` URL), the plain-text `body`
with `body_unsupported_nodes`, the original ADF document as `body_adf`,
`author`, `update_author`, `created_at`, `updated_at`, `jsd_public` and, for
a restricted comment, Jira's `visibility` map unchanged, such as
`%{"type" => "role", "value" => "Developers", "identifier" => "Developers"}`.
Keys without a value are left out. Jira lists only the comments that the
caller may see, and `total` counts only those.

Missing, empty and malformed bodies stay apart. A comment without a body has
no `body`, `body_adf` or `body_unsupported_nodes`. An empty ADF document gives
`body: ""` next to its `body_adf`. A body that is not valid ADF fails the page
with an `:invalid_response` error whose details name `body`, the comment ID
and the projection reason, without comment text.

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

Jira Cloud administrator webhooks, registered with a secret on the Jira
webhooks page or through `/rest/webhooks/1.0/webhook`, sign each delivery with
`X-Hub-Signature: sha256=<hex>`: the lowercase hex HMAC-SHA256 of the raw
request body under the webhook secret.

- **Signature verification**:
  `Jido.Connect.Jira.Webhook.Verification.verify_signature/3` checks that
  header against the exact raw body. A missing secret, a missing signature and
  any other format, such as bare hex, base64 or a `sha1=` prefix, return a
  `Jido.Connect.Error.AuthError`.
- **Delivery verification**: `Jido.Connect.Jira.Webhook.verify_delivery/4`
  checks the signature, decodes the body and returns a verified
  `Jido.Connect.WebhookDelivery` with `X-Atlassian-Webhook-Identifier` as
  `delivery_id`, `webhookEvent` as `event` and the normalized signal.
  `seen_delivery_ids:` marks a repeated identifier as a duplicate.
- **Event normalization**: `normalize_event/1` converts a raw Jira webhook
  payload into a flat signal map with stable field names. Issue events include
  changelog details; comment events include issue context.
- **Batch normalization**: `normalize_events/1` processes a list of events.

Deliveries of webhooks that Connect or OAuth 2.0 apps register follow a
separate contract; this package does not verify them. `verify_signature/2`
and `compute_signature/2` on `Jido.Connect.Jira.Webhook` are legacy helpers
for a base64 digest and do not match the header Jira sends.

### Webhook Event Fields

Issue events produce `jira.issue.changed` signals with:

- `event_type`, `change_type` (`"created"` or `"updated"`)
- `issue_event_type_name`: Jira's value, unchanged. It names the Jira event
  that fired, which depends on the operation and on the workflow transition;
  read status, assignee and due-date changes from the changelog items. In one
  capture run on 2026-10-30, with a simplified workflow and fields changed by
  REST edits, administrator webhooks sent a status change as `issue_generic`
  and assignee and due-date changes as `issue_updated`. Other workflows and
  the assign operation can send other names, such as `issue_assigned`,
  `issue_resolved` or `issue_work_started`.
- `actor_id`, `actor_name`: account ID and display name of the top-level `user`
- `issue_id`, `issue_key`, `project_key`, `project_name`, `summary`,
  `status_name`, `issue_type_name`, `priority_name`, `labels`
- `assigned`, `assignee_id`, `assignee_name`, `reporter_id`, `reporter_name`
- `created_at`, `updated_at`
- `changelog`: `id` and `items` in Jira's order. Each item has `field`,
  `field_id`, `field_type`, and the `from`, `from_string`, `to` and
  `to_string` keys that Jira sent.
- `matched_webhook_ids`, `timestamp`

Comment events produce `jira.comment.changed` signals with:

- `event_type`, `change_type` (`"created"` or `"updated"`)
- `actor_id`, `actor_name`
- `comment_id`, `comment_body`, `comment_body_unsupported_nodes`
- `comment_author_id`, `comment_author_name`
- `comment_created_at`, `comment_updated_at`
- `issue_id`, `issue_key` (context)
- `matched_webhook_ids`, `timestamp`

A field is absent when the delivery has no value for it. These fields follow
stricter presence rules:

- `assigned` is `true` when `fields.assignee` holds a user and `false` when
  Jira sends `"assignee": null`. It is absent when the fields leave the
  assignee out. `assignee_id` and `assignee_name` appear only with a user.
- Changelog items keep `from`, `from_string`, `to` and `to_string` exactly as
  present: a key sent as `null` stays `nil`, a key left out stays absent.
  Values pass through unchanged, so status items keep their status IDs and
  names, and due-date items keep date-only `YYYY-MM-DD` values.
- Comment deliveries have no top-level `user`. Their actor is
  `comment.author` for `comment_created` and `comment.updateAuthor` for
  `comment_updated`; without that object the actor is absent.
  `comment_author_id` always names the comment's author.
- `matched_webhook_ids` lists the `matchedWebhookIds` of a delivery as
  strings. Administrator webhooks do not send that key, so the field is
  absent for them. The per-delivery identifier is the `delivery_id` that
  `verify_delivery/4` reads from `X-Atlassian-Webhook-Identifier`. The
  undocumented `webhookID` is no longer read, and the signal field
  `webhook_id` is gone.
- `timestamp` is the delivery's epoch-millisecond `timestamp` as an ISO 8601
  string, such as `"2026-10-30T19:34:57.477Z"`.

`comment_body` follows the rich-text rules below. Administrator webhooks send
the body as a plain string, which passes through with an empty
`comment_body_unsupported_nodes`. A body that projects to an empty text keeps
`comment_body: ""`, so an empty comment stays apart from a delivery without a
body, which has neither body field.

`normalize_event/1` never raises on a malformed payload. It returns a
`Jido.Connect.Error.ProviderError` with reason `:invalid_webhook_event` for:

- a missing issue or comment, and an issue or comment `id` that is not a
  non-empty string;
- in issue deliveries, `fields`, `user`, `changelog` or `fields.assignee`
  that is neither an object nor `null`, `changelog.items` that is neither a
  list nor `null`, and a `changelog.items` entry that is not an object, a
  `null` entry included;
- in comment deliveries, `comment.author` or `comment.updateAuthor` that is
  neither an object nor `null`, and a comment body that is not valid ADF;
- a malformed `timestamp` or `matchedWebhookIds`.

Comment deliveries do not read `fields`, `user` or `changelog`. The error
details name the event type and the payload path, such as `"issue.id"`, and
for a comment body also the ADF reason; they hold no payload values. A
payload without a string `webhookEvent` returns `:invalid_webhook_event`
with empty details, and other event names return
`:unsupported_webhook_event`. `verify_delivery/4` then returns the verified
delivery without a normalized signal.

The signal keeps full values. `Jido.Connect.WebhookDelivery.to_public_map/1`
sanitizes `normalized_signal` like any transport payload: it cuts strings
such as a long `comment_body` at 512 bytes and replaces values nested deeper
than four levels, such as the values of changelog items, with
`"[truncated]"`.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:jira_reader` | Ordinary issue, comment, project, board, filter, transition, and field schema reads |
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

## Rich Text

Jira returns issue descriptions and comment bodies as Atlassian Document
Format (ADF). `Jido.Connect.Jira.ADFText` renders them with
`Jido.Connect.Atlassian.ADF.project/2` from `jido_connect_atlassian` in
`:degrade` mode:

- The text keeps document order and line boundaries for paragraphs, headings,
  list items and hard breaks. Links keep their target and mentions their
  display text.
- Node and mark types outside the supported subset, such as images
  (`mediaSingle`), macros (`extension`) or inline comments (`annotation`), are
  skipped. `Issue.description_unsupported_nodes`,
  `Comment.body_unsupported_nodes` and the signal field
  `comment_body_unsupported_nodes` list each skipped type once, in document
  order. Plain-string values pass through with an empty list.
- Malformed ADF and documents beyond the projection's depth or node-count
  limit fail explicitly. `Normalizer.issue/1` and `Normalizer.comment/1`
  return the projection's `Jido.Connect.Error.ValidationError`, issue reads,
  searches and comment lists return an `:invalid_response` provider error that
  names the field but not its content. Configure the limits through
  `jido_connect_atlassian`.
- `Comment.body_adf` keeps the original ADF document of a comment body. An
  empty document renders as `""`, which stays in `Comment.body`.

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

1. Register an administrator webhook with a secret in Jira, pointing to your
   endpoint URL.
2. Pass the raw request body, the request headers and the secret to
   `Jido.Connect.Jira.Webhook.verify_delivery/4`. It checks
   `X-Hub-Signature` before it decodes the body.
3. Use the `normalized_signal` of the returned delivery, or call
   `Jido.Connect.Jira.Webhook.normalize_event/1` on its payload.

The repository's live smoke harness captures deliveries through the demo host
and replays them through `verify_delivery/4`; see `docs/live_smoke_tests.md`.
Deliveries from apps that register webhooks follow a separate contract and do
not verify here.

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
