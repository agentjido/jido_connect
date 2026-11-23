# GitHub Auth

`jido_connect_github` supports GitHub OAuth Apps and GitHub Apps.

Use `Jido.Connect.AccountSetup` when a host needs both token import and OAuth.
The provider adapter returns the same credential shape for each setup path.
The host stores `credential.fields` in its vault and puts a reference to the
credential in the connection.

```elixir
alias Jido.Connect.AccountSetup
alias Jido.Connect.GitHub.AccountSetup, as: GitHubSetup

{:ok, credential} = AccountSetup.import_key(GitHubSetup, supplied_token)

{:ok, url, request} =
  AccountSetup.start_browser(GitHubSetup, current_principal, target, oauth_options)

# Save request in the host before redirecting to url.

{:ok, target, credential} =
  AccountSetup.finish_browser(
    GitHubSetup,
    current_principal,
    callback_state,
    callback_code,
    &MyApp.OAuthTransactions.consume/2,
    oauth_options
  )
```

Pass a separate configured `:redirect_uri` for each provider route, with the
same URI at authorization and code exchange. The host consumes the transaction
only for its authenticated owner. Save the credential only if that attempt
is still current. A new attempt or disconnect can invalidate an exchange that
is already in progress.

Use OAuth helpers for user-scoped tokens:

```elixir
url = Jido.Connect.GitHub.OAuth.authorize_url(opts)
{:ok, token} = Jido.Connect.GitHub.OAuth.exchange_code(code, opts)
```

Register the host's callback URL in the GitHub OAuth app. The host owns the
single-use state record and any PKCE verifier. Pass `:code_challenge` when you
build the authorization URL and `:code_verifier` when you exchange the code.

For headless authorization, enable device flow in the same OAuth app and call
`start_device_authorization/1` with the client ID and requested scopes. Show the
verification URI and user code. Keep the device code in the host process and
call `poll_device_authorization/2` at the interval GitHub returns. Increase the
interval by five seconds on `{:pending, :slow_down}`. Stop at expiry or on a
terminal error. The device flow does not need a callback route or client secret.
[GitHub OAuth app authorization](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)

Code exchange and device authorization return the same token fields. If GitHub
returns an expiration and refresh token, save the token pair together. Use
`refresh_token/2` from one worker at a time and save the replacement pair in one
update. GitHub can rotate the refresh token on use. Reconnect if GitHub rejects
an expired or revoked refresh token.

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
