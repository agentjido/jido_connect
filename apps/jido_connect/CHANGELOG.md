# Changelog

## 0.9.0 - Unreleased

- Move the MCP client bridge into core Connect with tools, resources, resource
  templates, prompts, completion, ping, status, notifications, and connection
  lifecycle support.
- Use ArborMCP `2.0.0-rc.6` for protocol and transports, including legacy notification
  listeners. Preserve endpoint fencing,
  credential leases, authorization, schema checks, notification scope, status
  deadlines, and host-owned client references.
- Use exact Jido and Jido Action Git revisions, Jido Signal `3.0.0-beta.5`,
  and ArborMCP `2.0.0-rc.6`.
- Make `Jido.Connect.Catalog.Item` the canonical catalog projection while the
  old tool paths remain narrow compatibility adapters.
- Upgrade generated Actions and catalog Actions to Jido Action v3 and remove
  the v2-only Action catalog projection.
- Remove the unused internal legacy descriptor builder and add direct coverage
  for the supported legacy lookup, search, and pack adapters.
- Remove the unpublished `jido_connect_mcp` application after its replacement
  tests and behavior moved into this package.

## 0.1.0

- Add the core `Jido.Connect` DSL, Zoi-backed contracts, generated Jido modules, and runtime adapters.
