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
    {:jido_connect_microsoft, "~> 0.8"}
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

## Product-Area Availability

The shared foundation tracks which Microsoft Graph product areas have
foundation-level support. Each area describes the shared scopes, foundation
contracts, and the expected product connector package name.

```elixir
# List all supported product areas
Jido.Connect.Microsoft.availability()
#=> [:mail, :calendar, :files, :contacts, :tasks, :teams]

# Fetch metadata for a specific area
{:ok, mail} = Jido.Connect.Microsoft.Availability.fetch(:mail)
mail.label         #=> "Outlook Mail"
mail.scopes         #=> ["Mail.Read", "Mail.ReadBasic", ...]
mail.product_package #=> :jido_connect_microsoft_outlook

# Read-only scopes for live smoke testing
Jido.Connect.Microsoft.Availability.read_only_scopes(:mail)
#=> ["Mail.Read", "Mail.ReadBasic"]

# Check foundation coverage
Jido.Connect.Microsoft.Availability.available?(:mail)   #=> true
Jido.Connect.Microsoft.Availability.available?(:unknown) #=> false
```

Product-area metadata is intentionally **scope and contract metadata only**.
It does not carry product-specific tools, actions, or triggers. Those belong
in product connector packages.

### Complete Availability Catalog

| Area | Label | Read-Only Scopes | Product Package |
|------|-------|-----------------|----------------|
| `:mail` | Outlook Mail | `Mail.Read`, `Mail.ReadBasic` | `jido_connect_microsoft_outlook` |
| `:calendar` | Microsoft Calendar | `Calendars.Read` | `jido_connect_microsoft_calendar` |
| `:files` | OneDrive / SharePoint Files | `Files.Read`, `Files.Read.All` | `jido_connect_microsoft_onedrive` |
| `:contacts` | Microsoft Contacts | `Contacts.Read` | `jido_connect_microsoft_contacts` |
| `:tasks` | Microsoft Tasks (To Do) | `Tasks.Read` | `jido_connect_microsoft_tasks` |
| `:teams` | Microsoft Teams | `Team.ReadBasic.All`, `Chat.Read` | `jido_connect_microsoft_teams` |

## Live Smoke Testing (Read-Only)

The Microsoft foundation package supports **read-only live smoke testing**
against the Microsoft Graph API using short-lived access tokens. This section
documents the expected setup and scope.

### Prerequisites

1. An Microsoft Entra ID (Azure AD) application registration.
2. OAuth credentials configured in `.env` (see `.env.example`).
3. A user account with consented scopes.

### Environment Variables

Set these in `.env` for live smoke testing:

```bash
MICROSOFT_CLIENT_ID=your-app-client-id
MICROSOFT_CLIENT_SECRET=your-app-client-secret
MICROSOFT_TENANT_ID=common
MICROSOFT_REDIRECT_URI=http://localhost:4000/integrations/microsoft/oauth/callback
MICROSOFT_ACCESS_TOKEN=short-lived-access-token
MICROSOFT_REFRESH_TOKEN=durable-refresh-token
MICROSOFT_USER_ID=me
```

Product fixture IDs for smoke tests:

```bash
MICROSOFT_OUTLOOK_MESSAGE_ID=    # A read-accessible message ID
MICROSOFT_CALENDAR_ID=            # A read-accessible calendar ID
MICROSOFT_EVENT_ID=               # A read-accessible event ID
MICROSOFT_ONEDRIVE_DRIVE_ID=      # A read-accessible drive ID
MICROSOFT_ONEDRIVE_ITEM_ID=       # A read-accessible item ID
```

### Read-Only Scope Recommendations

Live smoke tests should use the narrowest read-only scopes:

```elixir
# Read-only scopes by product area
Jido.Connect.Microsoft.Availability.read_only_scopes(:mail)
#=> ["Mail.Read", "Mail.ReadBasic"]

Jido.Connect.Microsoft.Availability.read_only_scopes(:calendar)
#=> ["Calendars.Read"]

Jido.Connect.Microsoft.Availability.read_only_scopes(:files)
#=> ["Files.Read", "Files.Read.All"]
```

### Foundation-Level Smoke Checks

The shared foundation package does not call product endpoints directly.
Product connectors own endpoint smoke tests. The foundation package supports
these offline-verified contracts:

1. **Auth URL construction** — `OAuth.authorize_url/1` builds a valid
   Microsoft OAuth URL with the configured scopes.

2. **Token exchange** — `OAuth.exchange_code/2` and `OAuth.refresh_token/2`
   handle token lifecycle (requires live credentials).

3. **Transport request construction** — `Transport.request/1` builds a
   valid authenticated Graph request with the correct base URL and headers.

4. **Scope normalization** — `Scopes.normalize/1`, `Scopes.encode/2`, and
   `Scopes.include?/2` validate scope sets without calling the API.

5. **Pagination helpers** — `Pagination.query/2`, `Pagination.values/1`,
   and `Pagination.next_link/1` handle OData pagination envelopes.

6. **Account normalization** — `Account.from_graph_user/2` normalizes
   Graph user payloads into a standard shape.

### What the Foundation Does NOT Smoke-Test

- Product endpoint calls (GET /me/messages, GET /me/events, etc.).
- Write, update, or delete operations on any Microsoft resource.
- Webhook subscription lifecycle.
- Delta query / change notification polling.

These operations belong in product connector package smoke tests.

## Shared Helpers

### Scopes

```elixir
Jido.Connect.Microsoft.Scopes.product(:mail)
Jido.Connect.Microsoft.Scopes.missing(granted_scopes, required_scopes)
```

### Transport

Build an authenticated Graph request:

```elixir
request = Jido.Connect.Microsoft.Transport.request(access_token)
```

Override the base URL (for sovereign cloud or proxy):

```elixir
request = Jido.Connect.Microsoft.Transport.request(access_token,
  base_url: "https://graph.microsoft.us/v1.0"
)
```

Normalize provider errors:

```elixir
{:error, error} = Jido.Connect.Microsoft.Transport.handle_error_response(response)
{:error, error} = Jido.Connect.Microsoft.Transport.invalid_success_response("bad payload", body)
```

Extract retry and rate-limit metadata:

```elixir
meta = Jido.Connect.Microsoft.Transport.response_metadata({:ok, raw_response})
# => %{rate_limited: true, retry_after: 30, request_id: "abc-123"}

Jido.Connect.Microsoft.Transport.rate_limited?({:ok, raw_response})
# => true when HTTP 429

Jido.Connect.Microsoft.Transport.retryable?({:ok, raw_response})
# => true for 429, 503, 504 and transport errors
```

### Pagination

Build OData query parameters:

```elixir
query = Jido.Connect.Microsoft.Pagination.query(%{}, page_size: 25)
# => %{:"$top" => 25}

query = Jido.Connect.Microsoft.Pagination.query(%{q: "test"}, page_size: 25, skip: 50)
# => %{q: "test", :"$top" => 25, :"$skip" => 50}
```

Extract pagination links from response bodies:

```elixir
next = Jido.Connect.Microsoft.Pagination.next_link(response_body)
delta = Jido.Connect.Microsoft.Pagination.delta_link(response_body)
```

Extract values and check for more pages:

```elixir
items = Jido.Connect.Microsoft.Pagination.values(response_body)
has_more = Jido.Connect.Microsoft.Pagination.has_more?(response_body)
```

Build checkpoint metadata for durable pagination cursors:

```elixir
checkpoint = Jido.Connect.Microsoft.Pagination.checkpoint(response_body, %{sync_id: "abc"})
# => %{next_link: "...", value_count: 25, sync_id: "abc"}
```
