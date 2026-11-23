# Generated Jido Modules

This document describes `release/3.0`. Use `release/2.0` for the old Jido v2
Plugin and Sensor contracts.

Each provider compiles to:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

These modules expose metadata through `jido_connect_projection/0` and delegate
execution to the core action, sensor, and plugin runtimes. Projections include
operation ids, resource/verb metadata, auth profile alternatives, policy
requirements, scopes, risk, confirmation, and generated module names.

Actions use the published Action v3 prerelease and static Zoi schemas. Use a
generated Action in a Flow step on a live Agent. For standalone calls, use
`Jido.Exec.run/4` and pass the Connect context explicitly. Set a deadline
when the host requires one.

Generated `.Plugin` modules expose Connect discovery through `actions/1`,
`subscriptions/2`, and `tool_availability/1`. `plugin_spec/1` returns a plain Connect map with `module`, `name`, and
`actions`; it does not return `Jido.Plugin.Spec`. Do not register these metadata
modules as v3 Agent Plugins. The host must declare its v3 Agent routes, schedule polling, and pass current execution
context. `Jido.Connect.Catalog.Plugin` is the runtime Plugin for catalog
configuration. It does not install routes or inject credentials. Catalog routes
are available as suggestions from `Jido.Connect.Catalog.Plugin.signal_routes/1`.

Add `Jido.Connect.Plugin` once and declare named bindings in `connect do`.
Select generated Actions and Trigger IDs on each binding. The host supplies
a `Jido.Connect.Context` for each binding used by the turn.

```elixir
source = Jido.Connect.Context.new!(%{
  tenant_id: tenant_id,
  actor: actor,
  connection: github_connection,
  policy: MyApp.GitHubPolicy,
  credential_resolver: MyApp.Credentials
})

Jido.AgentServer.call(server, signal, context: %{connect: %{source: source}})
```

The Signal carries Action input. The Context carries host facts and references
for access checks.
The host can use `Jido.Connect.Plugin.trigger(agent, binding_name, trigger_id)`
to read the provider Trigger contract for a declared selection. The Agent
declares which Flow or Action runs when the Signal arrives.

On each Agent Server turn, a generated Action selects its binding by Action
module and Signal type. A binding with no `signals` filter applies to any
Signal. Use distinct lists of exact Signal types when bindings share an
Action. Connect requires exactly one match, even if the host supplies live
context for only one of the matches.

Set `credential_resolver` on the binding to make the resolver module visible in
the Agent definition. Connect uses the binding resolver first, then an
explicit resolver option, then the Context resolver. Connect checks access
and requests a lease when the Action runs. The host owns credential storage
and sets the lease lifetime. See the
[credential lease lesson](../examples/00_start_here/00_04_credential_leases/README.md).

For per-call options, the host can pass
`%{integration_context: source, request_timeout_ms: 5_000}` as the binding
value. The same map supports explicit policy and resolver callbacks.

Sensor modules implement `Jido.Connect.Sensor`. They expose `init/2` and
`handle_event/2` callbacks without starting a process. The host applies the
returned schedule and emit instructions. A host that uses v3 SensorManager
must supply its own OTP driver. Webhook sensor modules remain metadata-only;
verified webhook processing uses the provider runtime.

Generated Actions and poll Sensors accept a Context with a resolved
`Jido.Connect.Connection` or a `Jido.Connect.ConnectionSelector`. For a
selector, set `connection_resolver: {Module, :function}` on the Context.
An explicit resolver callback in the options takes precedence. Keep raw
credentials in the host store. Execution requires a short-lived
`Jido.Connect.CredentialLease`.

The poll adapter keeps the supplied context in the returned state. Supply a
credential resolver to obtain a lease during each poll, or supply a current
lease before each `:tick`. Use `Jido.Connect.Sensor.replace_context/2` when the
host needs to supply fresh context. It keeps the checkpoint from the last
successful result. The host applies the returned schedule and emit instructions.

Generated plugin modules also expose `tool_availability/1` for host UIs and
agent planners that need to show which connector tools can be used before a
credential lease exists:

```elixir
Jido.Connect.Google.Drive.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.drive.files.list"],
  allowed_triggers: ["google.drive.file.changed"]
})
```

The result includes one entry per generated action and trigger with a stable
tool id, state, connection id when known, missing scopes when applicable, and
policy/configuration metadata. Availability states are `:available`,
`:connection_required`, `:missing_scopes`, `:disabled_by_policy`, and
`:configuration_error`.
