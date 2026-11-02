# Changelog

## Unreleased

- Add Jira Software board actions, saved-filter actions, issue transition
  discovery, destructive issue deletion, and Jira plan administration actions.
- Add strict nested plan validation, safe write previews, destructive gates,
  Jira administration policy requirements, and focused catalog packs.
- Disable automatic retries for filter share replacement and preserve uncertain
  delivery details for non-idempotent writes.
- Verify Jira administrator webhook signatures (`X-Hub-Signature:
  sha256=<hex>`) in `Jido.Connect.Jira.Webhook.Verification`, add
  `Jido.Connect.Jira.Webhook.verify_delivery/4`, and declare `:hmac_sha256` on
  both webhook triggers. `verify_signature/2` and `compute_signature/2` stay as
  legacy base64 helpers.
- Render issue descriptions, comment bodies and webhook comment bodies with
  the shared ADF projection of `jido_connect_atlassian` in `:degrade` mode,
  which keeps line boundaries, link targets and mention text. Add
  `Issue.description_unsupported_nodes`, `Comment.body_unsupported_nodes` and
  the `jira.comment.changed` signal field `comment_body_unsupported_nodes`.
  Plain-string bodies pass through. Malformed ADF now fails issue reads,
  searches and comment events explicitly instead of yielding partial text.
- Move `jira.issue.search` in place to Jira's enhanced JQL search,
  `POST /rest/api/3/search/jql`, because `POST /rest/api/3/search` answers
  `410 Gone`. Add `next_page_token` as input and output; `is_last` reports the
  last page. Default fields add `description`, `project` and `duedate`; a
  field list that names only `id` also requests `key`. Deprecated for one
  release: `start_at` accepts only `0`, and the outputs `total` and
  `start_at` stay declared but are never returned. `max_results`
  now reports the page size sent. Malformed pages and failed later pages
  return errors instead of empty results.
- Add `id`, `url`, `description`, `description_unsupported_nodes`,
  `due_date` and `missing_fields` to the `jira.issue.get` output.
  `missing_fields`, also on `Issue` and on each search result, lists requested
  field keys that Jira left out, apart from fields it returned as `null`.
  `*all` and `*navigable` count as the issue fields the connector reads, and a
  list that only excludes fields starts from Jira's selection for it. Custom
  fields behind a selector and other `*` selectors are not checked.
  `issue_key` accepts a numeric issue ID and is sent as one encoded path
  segment. `jira.issue.get`, `jira.issue.transition.list` and
  `jira.issue.delete` reject the keys `.` and `..` before a request.
- Return the nested status, assignee and reporter of issue reads as plain
  maps, which the `:map` outputs of the generated actions accept.
- Add `jira.issue.comment.list`, a read-only action that returns one page of
  an issue's comments, oldest first, through
  `GET /rest/api/3/issue/{issueIdOrKey}/comment` without rendered HTML. The
  page carries `issue` as supplied, `start_at`, `max_results`, `total`,
  `is_last` and `next_start_at`, which is absent on the last page. The page
  size defaults to 50 and accepts 1 to 100. Empty pages before the end and
  malformed pages fail. The reader and editor packs include the action.
- Add `url`, `body_adf` and `visibility` to `Comment`. A comment body that
  projects to `""` keeps `body: ""` instead of losing the field.

## 0.1.0

- Add the Jira provider package scaffold for Jido Connect.
