# Jido Connect

> This is the `release/3.0` maintainer development line. It follows Jido v3
> prereleases and is not ready for external adoption. See
> [branch support](https://github.com/agentjido/jido_connect/blob/release/3.0/docs/branch_support.md)
> and [the v3 dependency record](https://github.com/agentjido/jido_connect/blob/release/3.0/docs/v3_status.md).

`jido_connect` is the core package for authoring integration providers with a
Spark DSL and compiling them into concrete Jido actions, sensors, and plugins.

The package owns contracts and runtime boundaries only. Host applications own
durable connection storage, credential storage, audit storage, OAuth sessions,
and webhook HTTP ingress.

Core Zoi-backed contract modules live in individual files under
`lib/jido_connect/`, including `Jido.Connect.Spec`, `Jido.Connect.ActionSpec`,
`Jido.Connect.TriggerSpec`, `Jido.Connect.Context`,
`Jido.Connect.Connection`, `Jido.Connect.CredentialLease`,
`Jido.Connect.PolicyRequirement`, and `Jido.Connect.NamedSchema`.

Provider DSL modules use first-class sections for `integration`, `catalog`,
`schemas`, `auth`, `policies`, `actions`, and `triggers`. Generated projections
carry resource, verb, auth, policy, scope, risk, confirmation, and schema
metadata for host discovery and policy callbacks.

Large provider packages can split DSL declarations with `Spark.Dsl.Fragment`
and include them through `use Jido.Connect, fragments: [...]`; generated modules
still compile under the parent provider namespace.

New providers should use the canonical `access` and `effect` DSL forms. Legacy
operation fields are treated as compatibility inputs and should not be mixed
with the canonical form. Every action and trigger must declare `resource`,
`verb`, and `data_classification`.

## Installation

This development branch has not been published to Hex. For a local checkout,
add the core app as a path dependency:

```elixir
{:jido_connect, path: "../jido_connect/apps/jido_connect"}
```

The core app currently requires Elixir 1.19 or later, Jido Action
`3.0.0-beta.10`, and Jido Signal `3.0.0-beta.4`. See the packaged `mix.exs` for
the complete dependency set. A normal Hex dependency can replace the local
path after the v3 package is published.

## MCP Client Bridge

Core `jido_connect` includes client actions for MCP tools, resources, resource
templates, prompts, completion, and endpoint inspection. It also offers a
host-supervised notification session with connection lifecycle status. See the
[MCP bridge guide](guides/mcp_bridge.md) for the action list, scopes, and
session contract. ExMCP owns the protocol and transports.

Connect checks endpoint and tool allowlists, connections, credential leases,
scopes, policy, confirmation, schema drift, and uncertain write results. It
does not publish an MCP server or create dynamic proxy Actions.

For a host-owned ExMCP client, put the public endpoint ID in connection
metadata. Put the supervised client name or process reference in the
short-lived credential lease:

```elixir
connection =
  Jido.Connect.Connection.new!(%{
    id: "mcp-slack-tenant-1",
    provider: :mcp,
    profile: :endpoint,
    tenant_id: "tenant_1",
    owner_type: :tenant,
    owner_id: "tenant_1",
    status: :connected,
    scopes: ["mcp:tools:list", "mcp:tools:call", "mcp:endpoint:slack"],
    metadata: %{mcp_endpoint_id: "slack", connection_revision: 1}
  })

lease =
  Jido.Connect.CredentialLease.from_connection!(
    connection,
    %{mcp_client_ref: MyApp.SupervisedMCPClient},
    expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
    metadata: %{credential_version: 1}
  )
```

The host must start and supervise this ExMCP client. Connect does not stop a
host-owned client. The client reference must be secret-free. Keep credentials
in the supervised client process or in a connection-scoped endpoint definition.
A custom internal adapter can use `mcp_client_module`, but the default adapter
calls `ExMCP.Client` directly.

If a host cannot keep a shared supervised reference, the lease can contain an
`mcp_endpoint` definition instead. Connect then starts one ExMCP client for the
connection generation and stops only that client after the generation drains.
The endpoint definition supports ExMCP stdio, streamable HTTP, and BEAM-local
transports.

An application can also map a public endpoint ID to a host-supervised client:

```elixir
config :jido_connect,
  mcp_clients: %{
    filesystem: %{client_ref: MyApp.FilesystemMCPClient}
  }
```

Public endpoint IDs never act as ExMCP process references. Each lease-backed
connection also gets an opaque internal endpoint ID. Rotation, expiry,
revocation, or connection removal fences the old generation before Connect
stops a connection-scoped client. A remote write is sent at most one time. If
its result becomes unknown after the send boundary, Connect returns an
uncertain provider error and does not repeat the call.

Tool discovery returns `schema_hash`. A typed caller can give that value as
`expected_schema_hash` to `mcp.tool.call`. Connect lists the tool again and
rejects schema drift before the remote call.

The v3 development branch uses ExMCP `~> 1.4`. It does not depend on
`jido_mcp`.

## Host Boundary

A host app creates a durable `Jido.Connect.Connection`, mints a short-lived
`Jido.Connect.CredentialLease`, then calls generated Jido modules with both
values in context. Raw credentials should never be placed in plugin config,
agent state, or generated module metadata.

The top-level runtime API accepts either a provider module or a compiled
`Jido.Connect.Spec`, so host code can stay close to the provider it is using:

```elixir
Jido.Connect.invoke(Jido.Connect.GitHub, "github.issue.list", %{repo: "org/repo"},
  context: context,
  credential_lease: lease
)
```

X and Trello adapters also accept `request_timeout_ms` from the host. The value
must be a positive integer of at most 120,000 milliseconds. The provider keeps
its documented default when the option is absent. Core validates this option
for `invoke/4` and `commit/4` and passes it to the action handler. It does not
set a deadline for the whole runtime call. X and Trello use the value for their
remote request. The core MCP bridge uses its action input `timeout` and its
endpoint default. Other provider REST helpers do not currently use
`request_timeout_ms`; their own client timeouts apply.
`prepare/4` does not send a remote request, and polling does not use this
option.

Use `prepare/4` and `commit/4` for mutations that need confirmation. Prepare
does not call the provider. It returns an expiring, secret-free snapshot with a
safe preview. Commit requires the input and current runtime state again. It
rejects changes to the action, input, connection, lease, host binding,
execution ID, or idempotency key.

The lease check hashes `CredentialLease.to_public_map/1`. It does not hash raw
values in `CredentialLease.fields`. When the host rotates or replaces a
credential, it must mint a lease with a new, non-secret revision in
`metadata`, such as `credential_version: 2`. Pass that current lease to
`commit/4`. A prepared action bound to the prior revision will then fail the
stale-state check. Do not place tokens or other secrets in the revision or
lease metadata.

```elixir
{:ok, prepared} =
  Jido.Connect.prepare(MyConnector, "connector.item.create", input,
    context: context,
    credential_lease: lease,
    binding_ref: persona_binding_id,
    execution_id: execution_id,
    idempotency_key: idempotency_key
  )

Jido.Connect.commit(MyConnector, prepared, input,
  context: context,
  credential_lease: current_lease,
  binding_ref: persona_binding_id,
  execution_id: execution_id,
  idempotency_key: idempotency_key,
  execution_authorization: host_approval,
  authorization_validator: &MyApp.Approvals.validate/3
)
```

Persist a prepared action with its versioned, JSON-safe format. The format does
not contain the action input or credential fields:

```elixir
stored =
  prepared
  |> Jido.Connect.PreparedAction.dump()
  |> Jason.encode!()

{:ok, restored} =
  stored
  |> Jason.decode!()
  |> Jido.Connect.PreparedAction.load()
```

The format version is available from
`Jido.Connect.PreparedAction.format_version/0`. `load/1` rejects unknown
versions and invalid fields.

Boolean confirmation is not valid evidence. The host validates its own scoped
authorization record. Direct mutation calls are a temporary compatibility path
and emit a warning. Set `config :jido_connect, direct_mutation_mode: :deny` in a
strict host.

### Replay And Retry Safety

Prepare and commit validate that the approved request did not change. They do
not provide a durable one-use lock. Core does not store used prepared-action
IDs, execution IDs, or idempotency keys. If a host calls `commit/4` two times,
the provider can receive two requests.

Before commit, the host must atomically claim `prepared.id` in durable storage.
Only the worker that gets the claim can call the provider. Keep the claim when
the worker loses a response after it sent a mutation. A later worker must not
repeat that mutation unless the provider supports idempotent replay.

An `idempotency_key` is a bound runtime value. It does not stop duplicate calls
in core. Commit makes it available to the handler as
`context.execution.idempotency_key`. Set `provider_idempotency?: true` on an
action only when its handler sends that key to an API that gives an idempotency
guarantee.

Provider results use four delivery states:

- `:not_sent`: the request is known not to have left the client.
- `:rejected`: the provider returned a non-success response.
- `:response_received`: the client received the provider response.
- `:sent_outcome_unknown`: the request can have reached the provider, but the
  client did not receive the result.

Use `Jido.Connect.ProviderResponse.retry_guidance/1` or
`Jido.Connect.Error.retry_guidance/1`. `:retry_with_idempotency` requires the
same provider idempotency key. `:do_not_retry` prevents an automatic repeat of
an uncertain or failed 5xx non-idempotent mutation.

For host UI discovery, use `Jido.Connect.spec/1`, `actions/1`, `triggers/1`,
`auth_profiles/1`, or the richer `Jido.Connect.Catalog` APIs. `Catalog.discover/1`
returns provider entries; `Catalog.items/1` returns canonical action and trigger
items for search and operation pickers, including filters such as `:tag`,
`:resource`, `:verb`, `:auth_kind`, `:auth_profile`, and `:scope`.

## Canonical Catalog Items

`Jido.Connect.Catalog.Item` is the public read-only projection of one Connect
operation. The Connect specifications remain the execution definitions. An
item includes its provider identity, operation kind and ID, JSON schemas,
effect, confirmation, availability, auth profiles, scopes, policies, and
source metadata.

The stable item reference has the form `provider:kind:operation-id`:

```elixir
[
  %Jido.Connect.Catalog.Item{
    ref: "github:action:github.issue.create",
    provider: :github,
    type: :action,
    id: "github.issue.create"
  }
] =
  Jido.Connect.Catalog.items(
    modules: [Jido.Connect.GitHub],
    type: :action,
    tool: "github.issue.create"
  )

{:ok, item} =
  Jido.Connect.Catalog.describe_item("github:action:github.issue.create",
    modules: [Jido.Connect.GitHub]
  )
```

Use `items/1`, `search_items/2`, `lookup_item/2`, `describe_item/2`,
`call_item/3`, and `reviewed_items/2` for new code. A unique operation ID, the
old `provider.operation-id` form, and provider tuples still work during the
migration. Packs can use the canonical item reference and remain selection and
review data only.

The old `tools/1`, `search_tools/2`, `lookup_tool/2`, `describe_tool/2`,
`call_tool/3`, and `reviewed_descriptors/2` functions keep their prior return
types. They are narrow adapters over `Catalog.Item`. The catalog plugin also
keeps its search, describe, and call contract as Jido Action v3 modules.

The v2-only `action_catalog/1` adapter was removed. Use `items/1`,
`search_items/2`, and `reviewed_items/2` for Action discovery and selection.

## Catalog Plugin, Search, And Tool Calling

`Jido.Connect.Catalog` is the host-facing lookup layer for installed connector
tools. `Jido.Connect.Catalog.Plugin` is the canonical Jido plugin surface for
agents and hosts that want catalog lookup as actions. Both surfaces use the
same storage-free item data and the same core Connect execution boundary.

Search is deterministic in core. Exact ids and names rank first, then
resource/verb/label matches, then description, provider, tags, scopes, policies,
and source metadata. Results are stable by score, provider, then id:

```elixir
Jido.Connect.Catalog.search_tools("create github issue",
  type: :action,
  provider: :github
)
#=> [
#=>   %Jido.Connect.Catalog.ToolSearchResult{
#=>     tool: %Jido.Connect.Catalog.ToolEntry{
#=>       provider: :github,
#=>       id: "github.issue.create",
#=>       resource: :issue,
#=>       verb: :create,
#=>       scopes: ["repo"]
#=>     },
#=>     score: 1650,
#=>     matched_fields: [:id, :label, :resource, :verb]
#=>   }
#=> ]
```

`Jido.Connect.Catalog.Plugin.plugin_spec/1` returns Connect discovery data;
it does not install a Jido plugin. A host registers
`Jido.Connect.Catalog.Plugin` in its Agent and declares the routes it needs.
The plugin suggests these signal types and Action modules:

```elixir
[
  {"connect.catalog.search", Jido.Connect.Catalog.Actions.SearchTools},
  {"connect.catalog.describe", Jido.Connect.Catalog.Actions.DescribeTool},
  {"connect.catalog.call", Jido.Connect.Catalog.Actions.CallTool}
]
```

A routed catalog Action returns only its catalog result. Jido Action v3 uses
that output as the next Agent state. A host with other state must wrap the
catalog Action and return the complete next state. This example uses only the
core package and keeps `workspace` while it searches MCP tools:

```elixir
defmodule MyApp.CatalogSearch do
  use Jido.Action,
    name: "host_catalog_search",
    schema: Zoi.object(%{query: Zoi.string()}),
    output_schema:
      Zoi.object(%{workspace: Zoi.string(), catalog_results: Zoi.list(Zoi.any())})

  def run(params, %{agent_state: state} = context) do
    with {:ok, %{results: results}} <-
           Jido.Connect.Catalog.Actions.SearchTools.run(params, context) do
      {:ok, %{state | catalog_results: results}}
    end
  end
end

defmodule MyApp.CatalogAgent do
  use Jido.Agent, name: "connect_catalog_host"

  agent do
    schema Zoi.object(%{
      workspace: Zoi.string(),
      catalog_results: Zoi.list(Zoi.any()) |> Zoi.default([])
    })

    plugin Jido.Connect.Catalog.Plugin,
      config: %{modules: [Jido.Connect.MCP]}
  end

  routes do
    signal_source "/host"
    route "connect.catalog.search", MyApp.CatalogSearch
  end
end

agent =
  Jido.Agent.new!(MyApp.CatalogAgent,
    state: %{workspace: "tenant-1", catalog_results: []}
  )

signal = Jido.Signal.new!("connect.catalog.search", %{query: "mcp.tools"}, source: "/host")
{:ok, agent, []} = Jido.Agent.cmd(agent, signal)
# agent.state.workspace remains "tenant-1".
```

The host supplies current connection, lease, policy, and request controls in
the Action context when it calls a catalog tool. It keeps credentials out of
Agent state and plugin configuration. The test suite runs this wrapper through
`Jido.Agent.cmd/3`.

Lookups accept a bare tool id when it is unique, a provider-qualified string, a
`{provider, id}` tuple, or a `%Jido.Connect.Catalog.ToolEntry{}`:

```elixir
{:ok, tool} =
  Jido.Connect.Catalog.lookup_tool({"github", "github.issue.create"},
    modules: [Jido.Connect.GitHub]
  )

{:ok, same_tool} =
  Jido.Connect.Catalog.lookup_tool("github.issue.create",
    modules: [Jido.Connect.GitHub]
  )
```

Use `describe_tool/2` when a UI, agent, or bridge needs the full schema-rich
contract before asking a user for inputs:

```elixir
{:ok, descriptor} =
  Jido.Connect.Catalog.describe_tool({:github, "github.issue.create"},
    modules: [Jido.Connect.GitHub]
  )

Jido.Connect.Catalog.to_map(descriptor)
#=> %{
#=>   tool: %{id: "github.issue.create", type: :action, ...},
#=>   provider: %{id: :github, name: "GitHub", ...},
#=>   input: [%{name: :repo, type: :string, required?: true}, ...],
#=>   output: [%{name: :issue, type: :map, required?: true}],
#=>   input_json_schema: %{"type" => "object", "additionalProperties" => false, ...},
#=>   output_json_schema: %{"type" => "object", "additionalProperties" => false, ...},
#=>   schema_digest: "...",
#=>   strict?: true,
#=>   auth: [%{id: :user, kind: :oauth2, ...}],
#=>   scopes: ["repo"],
#=>   policies: [%{id: :issue_write, decision: :allow_if, ...}],
#=>   risk: :write,
#=>   confirmation: :required_for_ai,
#=>   provider_idempotency?: false,
#=>   source: :curated
#=> }
```

Catalog descriptors contain JSON-safe object schemas for action input/output
or trigger config/signal data. The object schemas reject unknown properties.
Field `minimum`, `maximum`, `min_length`, and `max_length` rules are in these
schemas. `schema_digest` is a stable SHA-256 digest of the canonical schema pair
and lets a client detect a contract change.

Only action tools are executable through `call_tool/4`. Trigger tools are
discoverable and describable, but return a structured validation error if a
caller tries to execute them through this path. `call_tool/4` delegates to
`Jido.Connect.invoke/4`, so it still enforces connection, credential lease,
expiry, auth profile, scopes, policy, and confirmation checks:

```elixir
connection =
  Jido.Connect.Connection.new!(%{
  id: "github-user-123",
  provider: :github,
  profile: :user,
  tenant_id: "tenant_123",
  owner_type: :user,
  owner_id: "user_123",
  subject: %{login: "octocat"},
  status: :connected,
  scopes: ["repo"]
})

lease =
  Jido.Connect.CredentialLease.from_connection!(connection,
    %{access_token: System.fetch_env!("GITHUB_ACCESS_TOKEN")},
    expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
  )

context = %Jido.Connect.Context{
  actor: %{type: :user, id: "user_123"},
  connection: connection
}

Jido.Connect.Catalog.call_tool(
  {:github, "github.issue.create"},
  %{repo: "acme/app", title: "Follow up", body: "Opened from a catalog call"},
  modules: [Jido.Connect.GitHub],
  context: context,
  credential_lease: lease
)
```

The same runtime values can come from action context when calling through the
catalog plugin:

```elixir
safe_issue_pack =
  Jido.Connect.Catalog.Pack.new!(%{
    id: "safe_github_issues",
    filters: %{provider: :github, type: :action, resource: :issue},
    allowed_tools: ["github.issue.list", "github.issue.create"]
  })

Jido.Connect.Catalog.Actions.CallTool.run(
  %{
    tool_id: "github.issue.create",
    input: %{repo: "acme/app", title: "Follow up"},
    pack: "safe_github_issues"
  },
  %{
    config: %{modules: [Jido.Connect.GitHub], packs: [safe_issue_pack]},
    context: context,
    credential_lease: lease
  }
)
```

Packs are restrictive curated views. Search only returns matching allowed tools,
and describe/call reject tools outside the pack:

```elixir
safe_issue_pack =
  Jido.Connect.Catalog.Pack.new!(%{
    id: "safe_github_issues",
    label: "Safe GitHub issue tools",
    filters: %{provider: :github, type: :action, resource: :issue},
    allowed_tools: ["github.issue.list", "github.issue.create"]
  })

Jido.Connect.Catalog.describe_tool("github.issue.create",
  modules: [Jido.Connect.GitHub],
  pack: "safe_github_issues",
  packs: [safe_issue_pack]
)
```

Rankers can optionally reorder deterministic candidates. Rankers receive only
sanitized catalog metadata: tool ids, labels, schemas, auth/scopes/policy names,
scores, and matched fields. They never receive credentials, leases, provider
responses, or raw host-private context. If a ranker raises or returns invalid
ids, core falls back to deterministic order and annotates result metadata:

```elixir
defmodule MyApp.ConnectToolRanker do
  def rank(_query, candidates) do
    candidates
    |> Enum.filter(&(&1.tool.provider == :github))
    |> Enum.map(&%{provider: &1.tool.provider, id: &1.tool.id, reason: "GitHub preferred"})
  end
end

Jido.Connect.Catalog.search_tools("open issue",
  modules: [Jido.Connect.GitHub, Jido.Connect.Linear],
  ranker: MyApp.ConnectToolRanker
)
```

AI-assisted lookup belongs in an optional package, not core. A future
`jido_connect_ai` package can use `req_llm` to suggest ranked candidate ids and
reasons, but execution should still go through `Jido.Connect.Catalog.call_tool/3`
and the same runtime safety checks.

Host apps can install only the provider packages they need. For example, a
Phoenix app that wants GitHub but not Slack should depend on
`jido_connect_github`; the provider package depends on `jido_connect` and
self-registers `Jido.Connect.GitHub` for catalog discovery. If Slack is not in
the host dependency graph, Slack is not compiled or listed by discovery.

Provider packages self-register catalog modules with application metadata:

```elixir
def application do
  [
    extra_applications: [:logger],
    env: [jido_connect_providers: [Jido.Connect.GitHub]]
  ]
end
```

`use Jido.Connect` generates the provider behavior callbacks and
`Jido.Connect.Catalog.Manifest` from the DSL. Connector authors should not
maintain a second manifest by hand; the compiled spec and generated projection
stay the source of truth.

For local development against the umbrella before Hex publishing, use explicit
path dependencies to the app folders:

```elixir
{:jido_connect, path: "../jido_connect/apps/jido_connect"},
{:jido_connect_github, path: "../jido_connect/apps/jido_connect_github"}
```

Provider packages are separate from the core Hex package. A host that uses a
provider adds that package as a separate dependency after it is published:

```elixir
{:jido_connect_github, "~> 0.8"}
```

Manual catalog registration remains available for private providers:

```elixir
config :jido_connect, catalog_modules: [MyApp.Connectors.Internal]
```

Authenticated generated actions and sensors require both a connection and a
matching credential lease. The connection is durable host-owned metadata; the
lease is short-lived credential material and has a redacted `Inspect`
implementation so accidental logs do not print tokens.

`CredentialLease` is the portable runtime auth envelope for provider packages.
Use `Jido.Connect.CredentialLease.from_connection/3` when minting a lease so it
copies non-secret binding metadata from the durable connection: provider,
profile, tenant, owner, subject, and effective scopes. This works the same for
user-level OAuth grants, tenant/org GitHub App installations, Slack workspace
bots, system API keys, and future connector-specific auth shapes. Runtime
authorization validates that the lease is active, belongs to the connection, and
does not claim broader scopes than the durable connection.

`ConnectionSelector` is the matching portable lookup intent: it describes which
connection a host should resolve for per-user, tenant/org, installation, system,
or explicit connection flows. `Jido.Connect.Authorization` then applies the
shared runtime checks across generated actions, sensors, plugin availability,
and future package bridges.

Host-owned policy stays outside the package but can be passed at runtime with
`policy:`. Core normalizes policy denial to `:policy_denied` and plugin
availability to `:disabled_by_policy`.

Availability distinguishes user-actionable connection states from package or
host configuration bugs. Missing or disconnected connections report
`:connection_required`; scope gaps report `:missing_scopes`; resolver, policy,
or dynamic scope failures that are not auth failures report
`:configuration_error` with sanitized error metadata.

Catalog discovery is lenient by default so one broken connector does not hide
the rest of the catalog. Use `Jido.Connect.Catalog.discover_with_diagnostics/1`
in CI, demo apps, and admin surfaces when you need to show unavailable
connectors and their structured failure reasons.

Provider packages should normalize reusable runtime shapes into the core
Zoi-backed structs:

- `Jido.Connect.CredentialLease` for short-lived credential material.
- `Jido.Connect.ProviderResponse` for provider HTTP/error envelopes.
- `Jido.Connect.WebhookDelivery` for verified webhook deliveries.
- `Jido.Connect.ConnectorCapability` for catalog-facing feature metadata.

```elixir
Jido.Connect.GitHub.Actions.ListIssues.run(
  %{repo: "org/repo"},
  %{integration_context: context, credential_lease: lease}
)
```

## Generated Modules

Every `use Jido.Connect` provider compiles thin generated modules:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

Generated modules expose `jido_connect_projection/0` for stable host
introspection and delegate execution to `Jido.Connect` runtimes.

Poll sensors are operational generated modules. Their `init/2` and
`handle_event/2` callbacks return schedule and emit instructions. The host
applies those instructions, schedules the next tick, and persists the
checkpoint when durability is required. Core delegates polling to
`Jido.Connect.poll/4` and emits `Jido.Signal`s.

Generated plugin subscriptions accept a shared `trigger_config` fallback or
per-trigger configs keyed by trigger id:

```elixir
Jido.Connect.GitHub.Plugin.subscriptions(
  %{
    trigger_configs: %{
      "github.issue.new" => %{repo: "org/repo"},
      "github.workflow_run.updated" => %{repo: "org/repo", branch: "main"}
    }
  },
  context
)
```

Webhook sensors are generated as metadata-only projections until a host delivery
contract is attached. Provider packages should verify signatures and normalize
webhook bodies with their pure webhook helper modules, then the host can route
the resulting `Jido.Connect.WebhookDelivery` or normalized signal into its own
HTTP, idempotency, and persistence flow. Calling a metadata-only generated
webhook sensor directly returns a structured execution error instead of silently
pretending the event was handled.

See the [generated-module contract](https://github.com/agentjido/jido_connect/blob/release/3.0/docs/generated_jido_modules.md)
for the host-owned route, scheduling, and credential boundaries.
