# Calendly Connector Guidance

- Keep Calendly-specific DSL, handlers, schemas, normalized structs, and tests
  in this package. Shared OAuth, transport, scope, and pagination helpers
  belong in `jido_connect` core or in a future shared package.
- Keep Calendly API v2 concerns in focused client modules as they are added.
- Prefer handwritten Req clients using `Jido.Connect.Provider.Transport` for
  the first implementation wave.
- Calendly PAT auth is recommended for development and CI. OAuth2 requires
  Calendly developer application registration.
- Calendly uses organization-scoped URIs (e.g. `https://api.calendly.com/users/me`)
  and resource URIs as identifiers. Normalized structs should extract short-form
  IDs when practical.
