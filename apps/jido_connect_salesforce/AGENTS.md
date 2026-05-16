# Salesforce Connector Guidance

- Keep Salesforce-specific DSL, handlers, schemas, normalized structs, and tests
  in this package. Shared OAuth, transport, scope, and pagination helpers
  belong in `jido_connect` core or in a future shared package.
- Keep Salesforce REST API concerns in focused client modules as they are added.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Salesforce uses org-specific instance URLs. The `:instance_url` credential
  field is required for all REST transport calls and is obtained from the
  OAuth token response.
- The OAuth2 connected-app flow with PKCE is the recommended auth mechanism
  for production. Username/password flow is for development and CI only.
- Salesforce access tokens are short-lived. The refresh flow must be
  implemented before production use.
- Do not log or expose access tokens, refresh tokens, client secrets, or
  signing secrets.
- Salesforce API version defaults to `60.0` and is configurable via
  application env.
