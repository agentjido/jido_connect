# Jido v3 AI agent with an MCP endpoint

This example runs a Jido v3 ReAct agent that reads a support handbook from a
local ArborMCP server through Jido Connect. Run it from the umbrella root:

```sh
mix deps.get
mix run examples/mcp_ai_agent/run.exs
```

Expected answer:

```text
The support desk opens at 09:30 UTC.
```

The default inference client scripts a tool call and builds its answer from
the tool result. The MCP server and the Jido agent both run in the BEAM.
The default run needs no model API key.

To use OpenAI for inference, set `OPENAI_API_KEY` in your environment and run:

```sh
mix run examples/mcp_ai_agent/run.exs -- --live
```

The live mode sends the question and MCP resource content to the model provider.

## How the request works

1. The host creates a Connect connection and a short-lived credential lease
   for the MCP endpoint. The connection grants read access to one resource.
2. `Jido.Connect.AI.CatalogToolSource` exposes the reviewed
   `mcp.resource.read` action to ReAct as a model tool.
3. The host passes the tool source, policy, and lease in the action context.
   The request signal contains only the question.
4. ReAct calls the tool. Connect checks the endpoint, resource scope, and
   policy, then reads the resource through ArborMCP. ReAct uses the returned
   text to answer.

For a remote server, the host can set a Streamable HTTP transport in the
lease instead of the fixture's BEAM transport. Use your server URL and path.

```elixir
%{
  mcp_endpoint: %{
    client_info: %{name: "handbook-agent"},
    transport:
      {:streamable_http,
       base_url: "https://mcp.example.com",
       mcp_path: "/mcp"}
  }
}
```

Select a resource URI that the remote server provides and update the host
scope and agent instructions to match it. For remote tool calls through
`mcp.tool.call`, use the
[Connect prepare and commit flow](../../apps/jido_connect/guides/mcp_bridge.md#prepare-and-call-a-tool).
