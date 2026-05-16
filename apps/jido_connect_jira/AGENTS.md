# Jira Connector Guidance

- Keep Jira-specific DSL, handlers, normalized structs, and tests in this
  package. Shared OAuth, transport, scope, and pagination helpers belong in
  `jido_connect` core or in a future shared package.
- Keep Atlassian Cloud API concerns in focused client modules under
  `Jido.Connect.Jira.Client.*`.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Jira API tokens are the recommended auth mechanism for development and CI.
  OAuth2 user flow requires a published Atlassian app.
- Do not log or expose API tokens, OAuth access tokens, refresh tokens, or
  client secrets.
- Keep DSL fragments small and grouped by capability. Prefer separate files for
  issues, projects, comments, and future webhook event families.
- Keep webhook verification separate from webhook event normalization when
  added.
