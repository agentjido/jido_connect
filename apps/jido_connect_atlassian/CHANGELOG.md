# Changelog

## Unreleased

- Add the shared Atlassian package for the Jira and Confluence packages.
- Move the strict ADF-to-text rendering and the bounded Markdown-to-ADF
  conversion here from `Jido.Connect.Confluence.ADF`.
- Add `Jido.Connect.Atlassian.ADF.project/2`, a text projection with
  `on_unsupported: :fail | :degrade` that returns `text` and
  `unsupported_nodes`, keeps line boundaries, link targets and mention text,
  and enforces configurable nesting depth and node count limits.
