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

Actions use the published Action v3 prerelease and static Zoi schemas. Run
them through `Jido.Exec.run/4`. Set an explicit timeout when the host requires
one; Action v3 does not supply the old 30-second default.

Generated `.Plugin` modules expose Connect discovery through `actions/1`,
`subscriptions/2`, and `tool_availability/1`. `plugin_spec/1` returns a plain Connect map with `module`, `name`, and
`actions`; it does not return `Jido.Plugin.Spec`. Do not register these metadata
modules as v3 Agent Plugins. The host must declare its v3 Agent routes, schedule polling, and pass current execution
context. `Jido.Connect.Catalog.Plugin` is the runtime Plugin for catalog
configuration. It does not install routes or inject credentials. Catalog routes
are available as suggestions from `Jido.Connect.Catalog.Plugin.signal_routes/1`.

Sensor modules implement `Jido.Connect.Sensor`. They expose `init/2` and
`handle_event/2` callbacks without starting a process. The host applies the
returned schedule and emit instructions. A host that uses v3 SensorManager
must supply its own OTP driver. Webhook sensor modules remain metadata-only;
verified webhook processing uses the provider runtime.

Generated actions and poll sensors expect the host to pass either a resolved
`Jido.Connect.Connection` inside `Jido.Connect.Context`, or a
`Jido.Connect.ConnectionSelector` plus a `connection_resolver` callback. In both
cases raw credentials stay out of agent context; execution still requires a
short-lived `Jido.Connect.CredentialLease`.

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
