# Jido Connect Microsoft

`jido_connect_microsoft` is the shared Microsoft Graph foundation package for
Microsoft provider packages in the `jido_connect` ecosystem.

It is intentionally not a product connector. Packages such as
`jido_connect_outlook`, `jido_connect_microsoft_calendar`, and
`jido_connect_onedrive` should depend on this package for common Microsoft
Graph contracts and helpers.

This package owns:

- Microsoft auth profile constants and metadata.
- Microsoft account/profile normalization.
- OAuth authorization URL and token exchange helpers.
- Credential lease helpers for short-lived Microsoft access tokens.
- Shared Microsoft Graph scope, pagination, transport, and error helpers.

This package does not own:

- Host credential storage.
- Host connection persistence.
- OAuth callback state persistence.
- Microsoft Graph product endpoint DSL declarations.
- Durable poll checkpoints or delta-link storage.

## Installation

```elixir
def deps do
  [
    {:jido_connect_microsoft, "~> 0.1.0"}
  ]
end
```

Most host applications should depend on a product package instead. Pull this
package directly only when building another Microsoft provider package or custom
Microsoft Graph connector.

## Package Shape

Microsoft product packages should keep product-specific endpoint logic in their
own package:

- Outlook logic belongs in `jido_connect_outlook`.
- Calendar logic belongs in `jido_connect_microsoft_calendar`.
- OneDrive logic belongs in `jido_connect_onedrive`.
- Teams logic belongs in `jido_connect_teams`.

Shared Microsoft Graph contracts and helpers belong here when they are
genuinely reusable across product packages.

## Auth Profiles

The shared package models one Microsoft auth profile:

- `:user` for OAuth authorization-code connections using Microsoft Entra ID.

The user profile can mint short-lived access-token leases. Host applications
still own durable credential storage and OAuth callback state.

```elixir
Jido.Connect.Microsoft.auth_profiles()
#=> [:user]

Jido.Connect.Microsoft.AuthProfiles.fetch!(:user)
```

## User OAuth

Build a Microsoft authorization URL:

```elixir
url =
  Jido.Connect.Microsoft.OAuth.authorize_url(
    client_id: System.fetch_env!("MICROSOFT_CLIENT_ID"),
    redirect_uri: "https://app.example.com/integrations/microsoft/oauth/callback",
    state: state,
    scope: [
      "openid",
      "email",
      "profile",
      "offline_access",
      "Mail.Read"
    ],
    prompt: "consent"
  )
```

Exchange an authorization code:

```elixir
{:ok, token} =
  Jido.Connect.Microsoft.OAuth.exchange_code(code,
    client_id: System.fetch_env!("MICROSOFT_CLIENT_ID"),
    client_secret: System.fetch_env!("MICROSOFT_CLIENT_SECRET"),
    redirect_uri: "https://app.example.com/integrations/microsoft/oauth/callback"
  )
```

Refresh a token from host-owned durable credential storage:

```elixir
{:ok, token} =
  Jido.Connect.Microsoft.OAuth.refresh_token(refresh_token,
    client_id: System.fetch_env!("MICROSOFT_CLIENT_ID"),
    client_secret: System.fetch_env!("MICROSOFT_CLIENT_SECRET")
  )
```

## Connections And Leases

Shape a durable, host-owned Microsoft connection from Graph user metadata:

```elixir
{:ok, connection} =
  Jido.Connect.Microsoft.Connections.user_connection(
    %{
      "id" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "mail" => "user@example.com",
      "displayName" => "User Name"
    },
    tenant_id: "tenant_1",
    credential_ref: "vault:microsoft:user:user@example.com",
    scopes: ["openid", "email", "profile", "offline_access"]
  )
```

Mint a short-lived credential lease from a refreshed access token:

```elixir
{:ok, lease} =
  Jido.Connect.Microsoft.OAuth.credential_lease(connection, token)
```

The lease contains only runtime credential material, such as `:access_token`.
Refresh tokens stay in host-owned durable storage.

## Shared Helpers

Scope catalog:

```elixir
Jido.Connect.Microsoft.Scopes.product(:mail)
Jido.Connect.Microsoft.Scopes.missing(granted_scopes, required_scopes)
```

Transport boundary:

```elixir
request = Jido.Connect.Microsoft.Transport.request(access_token)
```

Pagination helpers:

```elixir
query = Jido.Connect.Microsoft.Pagination.query(%{}, page_size: 25)
next = Jido.Connect.Microsoft.Pagination.next_link(response_body)
delta = Jido.Connect.Microsoft.Pagination.delta_link(response_body)
```
