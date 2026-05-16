# Airtable Connector Guidance

- Keep Airtable-specific DSL, handlers, schemas, normalized structs, and tests
  in this package. Shared OAuth, transport, scope, and pagination helpers
  belong in `jido_connect` core or in a future shared package.
- Keep Airtable API concerns in focused client modules as they are added.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Airtable personal access tokens are the recommended auth mechanism for
  development and CI. OAuth2 user flow requires a published Airtable OAuth app.
- Airtable OAuth tokens are short-lived. The refresh flow must be implemented
  before production use of the `:oauth2_user` profile.
- Do not log or expose personal access tokens, OAuth access tokens, refresh
  tokens, or client secrets.
