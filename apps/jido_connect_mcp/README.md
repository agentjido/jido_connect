# Jido Connect MCP

`jido_connect_mcp` is a bridge package that exposes configured MCP servers as
Jido Connect tools. It delegates transport and protocol work to `jido_mcp` and
keeps Connect responsible for policy, generated Jido modules, and credential
boundaries.

This package is intentionally conservative: tools are called through explicit
Connect actions, and endpoint and tool access is represented as scopes. Static
MCP server credentials can stay in `jido_mcp` endpoint configuration. A
persistent host can instead put one `%Jido.MCP.Endpoint{}` or endpoint attribute
map in the short-lived lease field `:mcp_endpoint`.

The host connection metadata can set `:mcp_endpoint_id` to the public endpoint
name. The bridge derives a separate internal Jido MCP string ID from the
connection ID. Thus, two connections can both expose `"slack"` without sharing
a client or credential. Credential rotation replaces the endpoint under the
same internal ID.

Tool discovery returns `schema_hash` for each remote input schema. A typed
connector can pass this value as `expected_schema_hash` to `mcp.tool.call`.
The bridge discovers the tool again and rejects a changed schema before it
calls the remote mutation.

## Catalog Plugin

Catalog search, description, and catalog-mediated execution now live in
`Jido.Connect.Catalog.Plugin`, not in an MCP-specific adapter. If an MCP bridge
or external agent needs a Connect tool catalog, expose the core plugin/actions:

- `connect.catalog.search` via `Jido.Connect.Catalog.Actions.SearchTools`
- `connect.catalog.describe` via `Jido.Connect.Catalog.Actions.DescribeTool`
- `connect.catalog.call` via `Jido.Connect.Catalog.Actions.CallTool`

Include `Jido.Connect.MCP` in the plugin config modules when MCP bridge tools
should be searchable:

```elixir
Jido.Connect.Catalog.Plugin.plugin_spec(%{
  modules: [Jido.Connect.MCP],
  packs: [
    Jido.Connect.Catalog.Pack.new!(%{
      id: "mcp_readonly",
      filters: %{provider: :mcp, type: :action},
      allowed_tools: ["mcp.tools.list"]
    })
  ]
})
```

Catalog calls still need the target provider runtime context and credential
lease. The MCP bridge endpoint credential is not reused as catalog/provider auth.
All execution still goes through `Jido.Connect.Catalog.call_tool/4`, which
delegates to the same runtime boundary as generated Jido actions.
