# MCP Client Bridge

Core `jido_connect` uses the pinned ExMCP Git commit in the
[v3 dependency record](../../../docs/v3_status.md) for MCP client protocol and
transports. Replace it with a fixed Hex release before package publication.
The `release/3.0` branch is for maintainer development with Action v3.

| Generated action | Required capability scope | Extra input |
| --- | --- | --- |
| `mcp.tools.list` | `mcp:tools:list` | Optional `cursor` |
| `mcp.tool.call` | `mcp:tools:call` | `tool_name`, `arguments` |
| `mcp.resources.list` | `mcp:resources:list` | Optional `cursor` |
| `mcp.resource_templates.list` | `mcp:resources:list` | Optional `cursor` |
| `mcp.resource.read` | `mcp:resources:read` | `uri` |
| `mcp.prompts.list` | `mcp:prompts:list` | Optional `cursor` |
| `mcp.prompt.get` | `mcp:prompts:get` | `prompt_name`, optional `arguments` |
| `mcp.completion.complete` | `mcp:completion:complete` | `ref`, `argument` |
| `mcp.endpoint.ping` | `mcp:endpoint:inspect` | None |
| `mcp.endpoint.status` | `mcp:endpoint:inspect` | None |

All actions require `endpoint_id` and the `endpoint_access` policy. They accept
an optional `timeout` in milliseconds, from 1 to 120,000. Tool calls retain the
Connect approval flow. Resources, prompts, completion, ping, and status return
`%{endpoint_id: id, result: mcp_result}`. MCP result keys remain strings.
List results retain `nextCursor`; pass it as `cursor` to get the next page.
Tool lists return normalized `tools` and optional `next_cursor` instead.
Schema checks for typed tool calls search up to 101 pages and reject cursor loops.

Connect does not publish an MCP server or own a general endpoint pool.
The host owns client callbacks, durable connections, credentials, policy,
approval records, and audit records.

## Install

For this development candidate, use a checkout of `release/3.0`. The branch
number is the Jido compatibility line; it is not a published Connect version.
After a package release, the normal core dependency has this form:

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

The old tool catalog functions remain narrow compatibility adapters. The
v2-only `action_catalog/1` adapter was removed. New code must use catalog
items.

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

All operations require the `:endpoint_access` policy. Pass a host policy with
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

Connect also binds the first observed schema hash for each tool to the current
connection generation. Later calls in that generation reject a different hash,
even if a caller updates `expected_schema_hash`. A new review does not change
an existing generation. After the host reviews a changed schema, it must
advance the durable `connection_revision` or lease `credential_version`, call
`Jido.Connect.MCP.EndpointLeaseManager.fence/2` with both new version values,
and use the updated connection and a fresh lease for the next call. For example,
if the current values are both `1`, the host can set `connection_revision: 2`,
keep `credential_version: 1`, and call:

```elixir
:ok =
  Jido.Connect.MCP.EndpointLeaseManager.fence(connection,
    connection_revision: 2,
    credential_version: 1
  )
```

The next acquisition starts a new generation with empty schema bindings. The
host must review the new hash and prepare a new approval. Old prepared calls
and leases must not be reused.

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
| Use reviewed Jido Actions | Generated Connect Action v3 modules |
| Use runtime dynamic proxy Actions | Reviewed `Catalog.Item` values, packs, and `call_item/3`; there is no runtime proxy replacement |
| Use MCP resources or prompts | Core Connect actions with endpoint and target scopes |
| Receive modern list-change or resource notifications | `Jido.Connect.MCP.Session` |
| Publish MCP servers or use direct protocol transports | ExMCP |
| Run coding-agent process lifecycles | Jido Harness |

Core Connect provides the client operations and managed notification sessions
listed above. Direct MCP protocol work and server publication belong in ExMCP.
No change to the `jido_mcp` package is required for this release candidate.


## Read Resources and Prompts

Use generated Actions with the same host context as tool calls:

```elixir
Jido.Connect.MCP.Actions.ReadResource.run(
  %{endpoint_id: "files", uri: "file:///report.txt"},
  %{integration_context: context, credential_lease: lease, policy: MyApp.MCPPolicy}
)

Jido.Connect.MCP.Actions.GetPrompt.run(
  %{endpoint_id: "files", prompt_name: "review", arguments: %{"text" => "Draft"}},
  %{integration_context: context, credential_lease: lease, policy: MyApp.MCPPolicy}
)
```

In addition to the capability scope, grant `mcp:endpoint:<id>` and
`mcp:resource:<uri>` or `mcp:prompt:<name>`. Wildcards are `mcp:endpoint:*`,
`mcp:resource:*`, and `mcp:prompt:*`. Completion requires a `ref/prompt` reference
with `name`, or a `ref/resource` reference with `uri`; the same target scope
applies. The `argument` map has string `name` and `value` fields. Remote
resource text and prompt messages are content, not host instructions.
The effective credential lease must also grant each required wildcard. A
wildcard on the durable connection does not extend a narrower lease.

## Notification Sessions

Use `Jido.Connect.MCP.Session` under the host supervisor. Each session has an
immutable filter and a managed endpoint lease. Static client configuration
alone is insufficient; pass the client reference through a credential lease.

```elixir
{:ok, session} = Jido.Connect.MCP.Session.start_link(
  "files",
  %{"resourcesListChanged" => true, "resourceSubscriptions" => ["file:///report.txt"]},
  context: context,
  credential_lease: lease,
  policy: MyApp.MCPPolicy,
  subscriber: self()
)

# Receive {:jido_connect_mcp, session, method, sanitized_params}.
# After ExMCP reconnects and reads fresh state, receive
# {:jido_connect_mcp, session, :resync, sanitized_snapshot}.
# Reconnect status arrives as {:jido_connect_mcp, session, :status, phase}.
Jido.Connect.MCP.Session.status(session)
Jido.Connect.MCP.Session.close(session)
```

Filters also support `toolsListChanged` and `promptsListChanged`. A session
requires `mcp:notifications:listen`, endpoint access, and the matching list or
resource-read scopes. This also authorizes the reads ExMCP makes during
resynchronization. Filters accept at most 100 resource URIs. Start a new
session to change its filter.

Sessions use MCP 2026-07-28 notification streams through `ExMCP.Client.listen/3`.
Configure that protocol on the host client or endpoint. Ordinary tools,
resources, and prompts also work with legacy peers. ExMCP 1.3 does not expose
legacy uncorrelated list-change/resource-update events through this subscription
API. Connect does not claim legacy notification delivery. Track this gap in
[#81](https://github.com/agentjido/jido_connect/issues/81).

A session stops when its subscriber or subscription stops, or when its lease
expires or is revoked. Lease checks run before event delivery and at 100 ms
intervals. Hosts must fence connections when credentials, scopes, or policy
change. Status reports `:active` or `:reconnecting`. A failed resynchronization open
sends the safe `:failed` status and closes the session. Monitor the session
process to detect closure. Connect releases the
lease and cancels the stream; it does not stop a host-owned client.

## Connection and Host Callback Contract

`EndpointLeaseManager` owns Connect leases and generation changes. ExMCP owns
handshake, capability negotiation, protocol errors, transports, and subscription
state. Connect-owned clients use bounded requests with automatic reconnect and
request retry disabled. Reopen them with a new connection generation. A host
that needs reconnect can supervise and configure its own ExMCP client.

Use ExMCP's public `Client.Handler` callbacks for roots, sampling, elicitation,
request progress, and log messages. Set the handler in the host client or in
trusted endpoint `client_options`; declare only supported capabilities. The
host applies its own approval and data policy to these server-initiated
requests. Connect never supplies an automatic sampling or elicitation approval.
Server publication and task-extension workflows are outside this client scope.
