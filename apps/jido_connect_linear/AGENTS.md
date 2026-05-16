# Linear Connector Guidance

- Keep Linear-specific DSL, handlers, normalized structs, and tests in this
  package. Shared OAuth, transport, scope, and pagination helpers belong in
  `jido_connect` core or in a future shared package.
- Keep Linear GraphQL API concerns in focused client modules under
  `Jido.Connect.Linear.Client.*`.
- The GraphQL transport boundary lives in `Jido.Connect.Linear.Client.Transport`.
  All Linear API traffic flows through it.
- Linear supports both API key (personal access token) and OAuth2 auth profiles.
  API keys are recommended for server-to-server integrations, development, and CI.
- Do not log or expose API keys, OAuth access tokens, refresh tokens, or client
  secrets.
- Keep DSL fragments small and grouped by capability. Prefer separate files for
  issues, teams, comments, and future webhook event families.
- Keep webhook verification separate from webhook event normalization.
