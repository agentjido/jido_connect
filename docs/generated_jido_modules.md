# Generated Jido Modules

Each provider compiles to:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

These modules expose metadata through `jido_connect_projection/0` and delegate
execution to the core action, sensor, and plugin runtimes. Projections include
operation ids, resource/verb metadata, auth profile alternatives, policy
requirements, scopes, risk, confirmation, and generated module names.

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
