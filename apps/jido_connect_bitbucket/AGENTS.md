# Bitbucket Connector Guidance

- Keep Bitbucket-specific DSL, client code, normalization, and tests in this
  package.
- Use the Bitbucket Cloud REST API v2 through focused client modules.
- Use Atlassian account email plus API token only for HTTP Basic
  authentication. Do not expose either leased credential field.
- Keep generated Jido actions thin. Provider handlers must delegate request and
  response work to the client boundary.
- Reject non-HTTPS endpoints and web links.
- Do not add write actions or generic HTTP or MCP call surfaces without a new
  reviewed action contract.
