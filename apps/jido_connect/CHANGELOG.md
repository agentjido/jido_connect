# Changelog

## 0.9.0 - 2026-08-25

- Move the narrow MCP tool-list and tool-call bridge into core Connect while
  preserving endpoint fencing, schema checks, and policy checks.
- Replace the temporary Jido MCP backend with stable ExMCP `1.x`, a narrow
  internal client contract, host-owned client references, and scoped client
  ownership without an endpoint pool.
- Make `Jido.Connect.Catalog.Item` the canonical catalog projection while the
  old tool paths remain narrow compatibility adapters.
- Upgrade generated Actions and catalog Actions to `jido_action`
  v3, remove the v2-only Action catalog projection, and use temporary exact
  Jido Action and Jido compatibility commits until their upstream releases
  land.
- Remove the unused internal legacy descriptor builder and add direct coverage
  for the supported legacy lookup, search, and pack adapters.
- Remove the unpublished `jido_connect_mcp` application after its replacement
  tests and behavior moved into this package.

## 0.1.0

- Add the core `Jido.Connect` DSL, Zoi-backed contracts, generated Jido modules, and runtime adapters.
