# Zendesk Connector Guidance

- Keep Zendesk-specific DSL, handlers, normalized structs, and tests in this
  package. Shared OAuth, transport, scope, and pagination helpers belong in
  `jido_connect` core or in a future shared package.
- Keep Zendesk REST API concerns in focused client modules under
  `Jido.Connect.Zendesk.Client.*`.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Zendesk API tokens are the recommended auth mechanism for development and CI.
  OAuth2 user flow requires a published Zendesk app.
- Do not log or expose API tokens, OAuth access tokens, refresh tokens, or
  client secrets.
- Keep DSL fragments small and grouped by capability. Prefer separate files for
  tickets, users, and future webhook event families.
- Do not implement ticket actions yet; this is a scaffold-only wave.
