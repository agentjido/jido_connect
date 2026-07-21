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
