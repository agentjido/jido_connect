# Changelog

## Unreleased

- `confluence.page.get` returns `url`, the tenant endpoint joined with the
  page's `_links.webui`. A missing or invalid link, or a `_links.base` other
  than the tenant endpoint, fails the read with the invalid-response error.
- `confluence.page.get` renders text with `Jido.Connect.Atlassian.ADF.project/2`.
  Links keep their target, for any scheme, and ordered list items their
  number.
- Page reads inherit the projection's limits, nesting depth 64 and 50,000
  nodes. A page beyond either, such as a table of 2,000 rows and 9 columns
  with about 56,000 nodes, now fails in both modes with the invalid-response
  error instead of returning its text; raise the limits with
  `config :jido_connect_atlassian, Jido.Connect.Atlassian.ADF`.
- Add the optional `confluence.page.get` input `on_unsupported`. `"fail"`, the
  default, keeps the invalid-response error for unsupported ADF content;
  `"degrade"` returns the supported text and adds `unsupported_nodes`.
- When the ADF projection rejects a page body, the invalid-response error of
  `confluence.page.get` adds `details.field` `"body"` and `details.adf_reason`,
  such as `:unsupported_adf_content` or `:adf_node_limit_exceeded`. Message,
  reason and `body_summary` stay as before.
- Move ADF conversion into the shared `jido_connect_atlassian` package.
  `Jido.Connect.Confluence.ADF` stays as a delegating alias; `to_text/1` and
  `from_markdown/1` keep their names, return shapes and results.

## 0.8.0

- Add the distinct Confluence Cloud provider identity.
- Add the six reviewed space and page actions.
- Add strict tenant URL validation and Basic-auth credential fencing.
- Add bounded Markdown-to-ADF and strict ADF-to-text conversion.
- Add optimistic page update checks and mutation-safe error handling.
- Add reader, editor, and destructive catalog packs.
