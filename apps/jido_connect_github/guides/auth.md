# GitHub Authentication

`jido_connect_github` supports GitHub OAuth Apps and GitHub Apps.

Use OAuth helpers for user-scoped tokens:

```elixir
url = Jido.Connect.GitHub.OAuth.authorize_url(opts)
{:ok, token} = Jido.Connect.GitHub.OAuth.exchange_code(code, opts)
```

Use GitHub App helpers for installation-scoped access:

```elixir
{:ok, lease} =
  Jido.Connect.GitHub.AppAuth.installation_credential_lease(
    installation_id,
    context,
    connection_id: connection.id
  )
```

Hosts should store installation ids and private key paths, not generated
installation tokens.
