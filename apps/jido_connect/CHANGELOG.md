# Changelog

## Unreleased

- Move the narrow MCP tool-list and tool-call bridge into core Connect while
  preserving endpoint fencing, schema checks, and policy checks.
- Replace the temporary Jido MCP backend with stable ExMCP `1.x`, a narrow
  internal client contract, host-owned client references, and scoped client
  ownership without an endpoint pool.

## 0.1.0

- Add the core `Jido.Connect` DSL, Zoi-backed contracts, generated Jido modules, and runtime adapters.
