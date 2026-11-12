# Changelog

## Unreleased

- `google.docs.document.get` returns tabs in Google's shape. `Tab` takes
  `tab_id` from `tabProperties.tabId` and `body` from `documentTab.body`, and
  carries nested tabs in the new `child_tabs` field. Before, `tab_id` and
  `body` stayed empty and nested tabs were dropped.
- A tab at any depth that is not a map, or whose fields do not have Google's
  shape, returns a `ProviderError` with reason `:invalid_response` instead of
  raising.
- The `include_tabs_content` description and the README state that `false`
  returns only the first tab in the legacy `body`, with `tabs` empty, and
  that the field has no default.
- `google.docs.document.get` accepts a connection that holds `documents`
  without `documents.readonly`. Before, such a connection failed with
  missing scopes, although Google accepts `documents` for reads.
- `google.docs.document.batch_update` returns `document_id` and
  `write_control`, Google's write control with the revision after the
  update. Before, the action result held only `replies`.
- The batch update allowlist drops `delete_table`, which Google does not
  have and rejects, and adds `delete_paragraph_bullets`. A batch with
  `delete_table` now fails validation before any request.
- A batch update response whose inline document is not a map or has a
  malformed tab returns a `ProviderError` with reason `:invalid_response`.
  Before, the document was dropped, or the handler raised.
- The README states that requests use snake_case names, which Google
  accepts as sent, and describes the response fields and revision
  conflicts.
- Document reads accept a connection that holds `drive` and neither
  `documents.readonly` nor `documents`. Before, such a connection failed
  with missing scopes, although Google answers a Docs read under `drive`.
  `drive.readonly` and `drive.file` still satisfy no read, and writes still
  require `documents`.
- The `:user` profile lists `drive` in `scopes` and `optional_scopes`, not
  in `default_scopes`. Before, the resolver accepted `drive` for reads, but
  catalog discovery and filtering by `drive` returned no Docs entry.
  `drive.readonly` and `drive.file` are not declared.
- The `include_tabs_content` description and the README state that an
  omitted value returns the same as `false`, checked live, and the README
  states that a Drive `text/plain` export holds every tab, nested tabs
  included, without tab titles.

## 0.1.0

- Initial Google Docs provider scaffold.
