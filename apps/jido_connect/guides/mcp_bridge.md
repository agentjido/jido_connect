# MCP Tool Bridge

Core `jido_connect` has a narrow MCP client bridge. It uses ExMCP `1.x` for
protocol behavior. It exposes only these Connect Action v2 operations:

- `mcp.tools.list`
- `mcp.tool.call`

The bridge does not publish an MCP server. It does not expose MCP resources or
prompts. It does not make dynamic proxy Actions. It does not own a general
endpoint pool.

## Install

Add core Connect to the host application:

```elixir
def deps do
  [
    {:jido_connect, "~> 0.9"}
  ]
end
```

The host owns durable connections, credential storage, policy decisions,
approval records, and audit records.

## Discover the Bridge

`Jido.Connect.Catalog.Item` is the canonical catalog projection:

```elixir
{:ok, list_item} =
  Jido.Connect.Catalog.lookup_item(
    "mcp:action:mcp.tools.list",
    modules: [Jido.Connect.MCP]
  )
```

The old tool catalog functions and `action_catalog/1` remain Action v2
adapters. New code must use catalog items.

## Configure a Client

The public endpoint ID and the ExMCP client reference are different values.
The endpoint ID is safe catalog and policy data. A process name or reference
is runtime data and must not contain a credential.

A host can supervise an ExMCP client and put its reference in a short-lived
credential lease:

```elixir
connection =
  Jido.Connect.Connection.new!(%{
    id: "mcp-files-tenant-1",
    provider: :mcp,
    profile: :endpoint,
    tenant_id: "tenant-1",
    owner_type: :tenant,
    owner_id: "tenant-1",
    status: :connected,
    scopes: [
      "mcp:tools:list",
      "mcp:tools:call",
      "mcp:endpoint:files",
      "mcp:tool:read_text_file"
    ],
    metadata: %{mcp_endpoint_id: "files", connection_revision: 1}
  })

lease =
  Jido.Connect.CredentialLease.from_connection!(
    connection,
    %{mcp_client_ref: MyApp.FilesMCPClient},
    expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
    metadata: %{credential_version: 1}
  )
```

Connect does not stop a host-owned client. The host keeps credentials in that
client process.

For a fixed local endpoint, the host can map a public endpoint ID to a
supervised client reference:

```elixir
config :jido_connect,
  mcp_clients: %{
    files: %{client_ref: MyApp.FilesMCPClient}
  }
```

If the lease has an `mcp_endpoint` definition, Connect starts one ExMCP client
for that connection generation. It stops that client after the generation
drains. The endpoint type supports ExMCP stdio, streamable HTTP, and BEAM-local
transports. This is connection-scoped ownership, not an endpoint pool.

## Apply Scopes and Policy

The bridge checks these scopes:

- `mcp:tools:list`
- `mcp:tools:call`
- `mcp:endpoint:<endpoint-id>`
- `mcp:tool:<tool-name>` for a tool call

Both operations require the `:endpoint_access` policy. Pass a host policy with
`policy:` when you invoke, prepare, or commit an operation. The callback gets
the operation, input, actor context, connection, and policy data. It returns
`:ok` to allow access or an error to deny access.

## List Tools

Call the list operation through the normal Connect runtime:

```elixir
{:ok, result} =
  Jido.Connect.invoke(
    Jido.Connect.MCP,
    "mcp.tools.list",
    %{endpoint_id: "files"},
    context: context,
    credential_lease: lease,
    policy: MyApp.ConnectPolicy
  )
```

Each tool result has a `schema_hash`. Keep this hash with a reviewed tool
selection.

## Prepare and Call a Tool

`mcp.tool.call` has an external-write effect. An AI caller must use
`prepare/4` and `commit/4`. The host must store a durable, one-use approval
claim. Core validates that claim through the supplied authorization callback.

```elixir
input = %{
  endpoint_id: "files",
  tool_name: "read_text_file",
  arguments: %{"path" => "/data/report.txt"},
  expected_schema_hash: reviewed_schema_hash
}

{:ok, prepared} =
  Jido.Connect.prepare(Jido.Connect.MCP, "mcp.tool.call", input,
    context: context,
    credential_lease: lease,
    policy: MyApp.ConnectPolicy,
    execution_id: execution_id,
    idempotency_key: idempotency_key
  )

{:ok, result} =
  Jido.Connect.commit(Jido.Connect.MCP, prepared, input,
    context: context,
    credential_lease: current_lease,
    policy: MyApp.ConnectPolicy,
    execution_id: execution_id,
    idempotency_key: idempotency_key,
    execution_authorization: approval,
    authorization_validator: &MyApp.Approvals.validate/3
  )
```

Connect lists the tool again before the call. It rejects the call if
`expected_schema_hash` does not match the current input schema.

The host must not retry a tool call after an unknown send result. Connect
returns a `Jido.Connect.Error.ProviderError` with reason
`:mcp_write_uncertain` and delivery state `:sent_outcome_unknown`. The host
must reconcile the remote state before it makes a new call.

## Move from `jido_mcp`

Use this migration map:

| Previous use | New owner or path |
| --- | --- |
| List tools or call a reviewed tool | Core `Jido.Connect.MCP` |
| Register an endpoint in a shared pool | A host-supervised client reference or a connection-scoped lease endpoint |
| Use the two reviewed Jido Actions | Generated Connect Action v2 modules for the two bridge operations |
| Use runtime dynamic proxy Actions | Reviewed `Catalog.Item` values, packs, and `call_item/3`; there is no runtime proxy replacement |
| Use MCP resources, prompts, servers, or direct protocol transports | ExMCP |
| Run coding-agent process lifecycles | Jido Harness |

Core Connect is not a drop-in replacement for all `jido_mcp` features. It
replaces only the reviewed tool-list and tool-call path. Direct MCP protocol
work belongs in ExMCP.
