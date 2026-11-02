# Changelog

## Unreleased

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
