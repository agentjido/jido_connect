# Jido Connect GitHub

`jido_connect_github` is the GitHub provider package for `jido_connect`.

It includes:

- `Jido.Connect.GitHub`, a Spark-authored provider that compiles into Jido tools
- GitHub issue actions and a poll sensor
- OAuth App helpers in `Jido.Connect.GitHub.OAuth`
- GitHub App helpers in `Jido.Connect.GitHub.AppAuth`
- connection-shaping helpers in `Jido.Connect.GitHub.Connections`
- REST client helpers in `Jido.Connect.GitHub.Client`
- Webhook verification and normalization in `Jido.Connect.GitHub.Webhook`

The Spark DSL declaration lives in
`lib/jido_connect/github/integration.ex`. Provider handlers live under
`lib/jido_connect/github/handlers/`.

See the [authentication guide](guides/auth.md) and
[webhook guide](guides/webhooks.md) for host setup.

## Installation

```elixir
def deps do
  [
    {:jido_connect_github, "~> 0.8"}
  ]
end
```

## GitHub App Flow

Hosts store the GitHub App private key path and installation id, then mint a
short-lived credential lease when a Jido tool runs:

```elixir
{:ok, lease} =
  Jido.Connect.GitHub.AppAuth.installation_credential_lease(
    installation_id,
    %{tenant_id: "tenant_1", actor: %{id: "user_1"}},
    connection_id: "conn_1"
  )
```

GitHub App installations can be organization-level or user-account-level. Use
`Jido.Connect.GitHub.Connections.installation_connection/2` to shape the
durable, host-owned `Jido.Connect.Connection` consistently:

```elixir
{:ok, connection} =
  Jido.Connect.GitHub.Connections.installation_connection(
    %{
      id: 42,
      account: %{login: "my-org", type: "Organization"},
      repository_selection: "all",
      permissions: %{metadata: "read", issues: "write"}
    },
    tenant_id: "tenant_1"
  )
```

Organization installations default to `owner_type: :tenant`. User-account
installations default to `owner_type: :app_user`. The GitHub account and
installation identity live in `connection.subject`; the host app still owns
persistence and credential storage.

For user OAuth/manual-token connections:

```elixir
{:ok, connection} =
  Jido.Connect.GitHub.Connections.user_connection(
    %{login: "octocat", scope: "repo read:user"},
    tenant_id: "tenant_1"
  )
```

## Catalog Packs

The provider includes catalog-pack templates for common agent roles:

```elixir
Jido.Connect.GitHub.CatalogPacks.read_only()
Jido.Connect.GitHub.CatalogPacks.issues_read()
Jido.Connect.GitHub.CatalogPacks.issues_manage()
Jido.Connect.GitHub.CatalogPacks.full()
```

The issue packs use explicit Action lists. The `read_only/0` and `all/0` packs
use filters and can include new matching Actions after a package update.

Create a Jido AI source from a pack:

```elixir
{:ok, source} =
  Jido.Connect.AI.CatalogToolSource.new(
    Jido.Connect.GitHub,
    Jido.Connect.GitHub.CatalogPacks.issues_read()
  )
```

Only read-only packs can become Jido AI tool sources. Mutation packs stay
blocked until the host integrates Jido AI review with `Jido.Connect.prepare/4`
and `Jido.Connect.commit/4` authorization.

## Webhooks

Use `Jido.Connect.GitHub.Webhook.verify_request/3` from a Plug or Phoenix
controller before normalizing event payloads. The package verifies signatures
and produces signal-shaped maps for `issues.opened`; the host owns persistence
and delivery dedupe. Webhook verification requires a configured secret.

## Live Testing Notes

GitHub's list endpoints can lag immediately after issue writes. For
read-after-write demos, retry generated `ListIssues` briefly before treating a
missing just-created issue as a failure. Cleanup flows can use
`Jido.Connect.GitHub.Client.close_issue/3`.
