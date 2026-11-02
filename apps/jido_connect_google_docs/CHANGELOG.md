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

## 0.1.0

- Initial Google Docs provider scaffold.
