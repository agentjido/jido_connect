# Changelog

## 0.9.0 - Unreleased

- Move the MCP client bridge into core Connect with tools, resources, resource
  templates, prompts, completion, ping, status, notifications, and connection
  lifecycle support.
- Use ExMCP `1.4` for protocol and transports. Preserve endpoint fencing,
  credential leases, authorization, schema checks, notification scope, status
  deadlines, and host-owned client references.
- Use Jido `3.0.0-beta.1`, Jido Action `3.0.0-beta.11`, and Jido Signal
  `3.0.0-beta.4` from Hex.
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
