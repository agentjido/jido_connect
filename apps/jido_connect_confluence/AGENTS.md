# Confluence Connector Guidance

- Keep Confluence-specific DSL, client code, normalization, ADF conversion, and
  tests in this package.
- Use the official Confluence Cloud REST API v2 through focused client modules.
- Bind Basic credentials only to the validated `metadata.site_url` tenant under
  `atlassian.net`.
- Keep generated Jido actions thin. Handlers delegate request and response work
  to the client boundary.
- Do not log or expose Atlassian account emails, API tokens, raw provider
  response bodies, or credential lease fields.
- Do not add generic HTTP actions, delete to the editor pack, or unreviewed page
  operations without a new action contract.
