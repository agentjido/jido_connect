# Changelog

## 0.9.0 - 2026-08-25

- Move the narrow MCP tool-list and tool-call bridge into core Connect while
  preserving endpoint fencing, schema checks, and policy checks.
- Replace the temporary Jido MCP backend with stable ExMCP `1.x`, a narrow
  internal client contract, host-owned client references, and scoped client
  ownership without an endpoint pool.
- Make `Jido.Connect.Catalog.Item` the canonical catalog projection while the
  old tool paths and `action_catalog/1` remain Action v2 adapters.
- Remove the unused internal legacy descriptor builder and add direct coverage
  for the supported legacy lookup, search, and pack adapters.
- Remove the unpublished `jido_connect_mcp` application after its replacement
  tests and behavior moved into this package.

## 0.1.0

- Add the core `Jido.Connect` DSL, Zoi-backed contracts, generated Jido modules, and runtime adapters.
