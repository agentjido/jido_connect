# Host-Owned Storage

`jido_connect` intentionally does not ship Ecto schemas, migrations, storage
behaviours, or adapters.

Hosts own:

- durable connection records
- credential storage
- OAuth state/session persistence
- webhook delivery dedupe
- run and event audit history
- persona records and persona-to-connection bindings
- prepared-action approvals and atomic execution claims

The package contracts are `Jido.Connect.Connection`,
`Jido.Connect.ConnectionSelector`, `Jido.Connect.CredentialLease`,
`Jido.Connect.Run`, and `Jido.Connect.Event`.

`CredentialLease` is the portable credential handoff between host-owned storage
and any generated action, sensor, or bridge call. Provider packages mint leases
from OAuth token exchanges, app installation token creation, API keys, or
host-configured bridge credentials; handlers read only from `lease.fields`.

## Connection Ownership

`Connection` records describe durable grants owned by a host principal:

- `owner_type: :user` for per-user OAuth credentials.
- `owner_type: :tenant` for tenant-wide shared installs, such as a Slack bot.
- `owner_type: :org` for organization-wide grants.
- `owner_type: :installation` for app installation grants, such as GitHub App
  installations.
- `owner_type: :system` for app-controlled credentials.

`jido_connect` validates resolved connections, profiles, scopes, and short-lived
leases. The connector DSL can declare policy requirements such as
`:repo_access` or `:workspace_access`, and generated projections expose those
requirements to host UIs, but the actual decision about whether an actor may use
a shared credential belongs to the host app.

## Host Policy

Pass a policy callback when actor-level authorization matters:

```elixir
policy = fn operation, params, context, connection ->
  if MyApp.Permissions.allowed?(context.actor, operation.id, connection) do
    :ok
  else
    {:deny, :not_allowed_for_connection}
  end
end

Jido.Connect.GitHub.Actions.ListIssues.run(params, %{
  integration_context: context,
  credential_lease: lease,
  policy: policy
})
```

Policies may be anonymous functions, modules exporting `authorize/4` or
`authorize/5`, or `{module, function}` tuples. Denials return
`Jido.Connect.Error.AuthError` with `reason: :policy_denied`. Policy exceptions
are normalized into `Jido.Connect.Error.ExecutionError` instead of escaping as
raw exceptions.

Generated plugin availability accepts the same `policy` and `context` config.
Policy denial is reported as `:disabled_by_policy` so UIs can hide or disable
tools without exposing connection internals.

## Connection Selectors

Use `ConnectionSelector` when the caller knows which kind of credential should
be used but the host still needs to load the durable connection:

```elixir
{:ok, selector} =
  Jido.Connect.ConnectionSelector.tenant_default(:slack, "tenant_1",
    profile: :bot,
    required_scopes: ["chat:write"]
  )
```

Generated Jido actions and sensors can receive a context with a
`connection_selector` plus a host resolver:

```elixir
Jido.Connect.Slack.Actions.PostMessage.run(params, %{
  integration_context: %Jido.Connect.Context{
    tenant_id: "tenant_1",
    actor: %{id: "user_1", type: :user},
    connection_selector: selector
  },
  connection_resolver: &MyApp.Connections.resolve!/1,
  credential_lease: lease
})
```

The resolver returns a `Jido.Connect.Connection`. The host still mints the
matching `CredentialLease` from its credential store. `CredentialLease.from_connection/3`
is the preferred constructor because it copies provider, profile, tenant,
owner, subject, and granted scopes from the durable connection.

Core then checks:

- the lease has not expired
- the connection id matches the lease
- the connection is connected
- the resolved connection matches the selector
- the connection profile is allowed for the operation
- the host policy allows this actor to use the connection
- the connection and effective lease scopes satisfy required scopes

If a lease carries its own scopes, the effective scopes are the intersection of
connection scopes and lease scopes. This lets hosts narrow a short-lived lease
without weakening the durable connection grant.

Plugin availability accepts the same selector/resolver pattern, so UIs can
show whether shared tenant or installation tools are available without exposing
raw credentials.

Persona selection stays outside Jido Connect. A host resolves the persona to an
exact connection and passes a stable `binding_ref` during both prepare and
commit. Jido Connect hashes that binding with the action, input, connection,
and public lease identity. Commit fails when the binding or other state changes.
