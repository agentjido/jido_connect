# Nextcloud Connector Guidance

- Keep this as a single provider package. Split implementation by capability
  using modules and Spark fragments, not package boundaries.
- Treat `base_url` as credential/connection data. Handlers must use the
  credential lease and must not fall back to arbitrary untrusted input without
  host policy checks.
- Default to Nextcloud app-password auth for API access. OAuth2 is supported as
  metadata and helpers, but Nextcloud's built-in OAuth2 has no provider-side
  scopes, so hosts should treat it as broad account access.
- Use WebDAV for file operations and OCS for shares, capabilities, and Talk.
- Use a real XML parser for DAV/OCS XML. Do not parse XML with regex or string
  matching.
- Do not log or expose app passwords, OAuth access tokens, refresh tokens,
  Office external-app secrets, or Collabora/WOPI launch tokens.
