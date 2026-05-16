# Jido Connect Salesforce

Salesforce CRM provider package for Jido Connect.

This package provides a Salesforce integration for Jido Connect, supporting
contacts, accounts, and opportunities via the Salesforce REST API.

## Status

This is an **experimental** scaffold. Action fragments, normalized structs,
and catalog packs will be expanded in subsequent waves.

## Auth Profiles

The provider supports two authentication profiles:

- **OAuth2 connected-app** (`:oauth2_connected_app`): Standard OAuth2
  authorization code flow with PKCE against a Salesforce connected app.
  Recommended for production integrations. Grants scoped access on behalf of
  a Salesforce user.

- **Username/password** (`:username_password`): Salesforce username-password
  OAuth flow for development and CI. Authenticates using org credentials
  directly.

## Instance URL Handling

Salesforce REST APIs are scoped to an org-specific instance URL
(e.g., `https://myorg.my.salesforce.com`). The instance URL is obtained from
the OAuth token response and stored as a credential field (`:instance_url`).
The REST transport boundary uses this URL as the base for all API requests.

## Salesforce OAuth Scopes

| Scope | Description |
|---|---|
| `api` | Access to Salesforce REST API |
| `refresh_token,offline_access` | Long-lived token refresh |
| `cdp_api` | Customer Data Platform access (optional) |

## API Version

The REST transport targets Salesforce API version `60.0` by default,
configurable via application env:

```elixir
config :jido_connect_salesforce, salesforce_api_version: "61.0"
```

## API Boundaries

All Salesforce API traffic uses
`Jido.Connect.Salesforce.Client.Transport.api_request/3`, which builds bearer
requests against the org-specific instance URL and API version.

## Catalog Packs

The provider ships two curated catalog packs for scoping tool discovery
and invocation:

| Pack | Risk | Description |
|------|------|-------------|
| `:salesforce_reader` | read | Contact queries |
| `:salesforce_editor` | write | Reader + contact mutations |

Triggers are subscribed to independently and are not listed in packs.

### Scope Matrix

Each action maps to the narrowest set of Salesforce scopes required:

| Operation | Required Scopes |
|-----------|----------------|
| `salesforce.contacts.contact.get` | `api` |
| `salesforce.contacts.contact.list` | `api` |
| `salesforce.contacts.contact.create` | `api` |

### Privacy Classification

| Operation | Classification | Risk | Confirmation |
|-----------|---------------|------|-------------|
| Contact get/list | `personal_data` | read | none |
| Contact create | `personal_data` | write | required_for_ai |

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
generated plugin surface through injected fake clients and does **not** call
live Salesforce APIs.

### Running Against a Live Salesforce Org

When you need to validate against a real Salesforce org:

1. **Use a dedicated Salesforce Developer Edition or Sandbox** — never
   production orgs.

2. **Use the username/password flow for CI** — store org credentials in
   environment variables, never in version control.

3. **Do not hardcode tokens** — store access tokens, refresh tokens, and
   client secrets in environment variables or a secrets manager.

4. **Start with the reader pack** — validate read-only actions first.

5. **Upgrade to editor for write tests** — once read actions pass, switch
   to the `:salesforce_editor` pack.

6. **Clean up test data** — remove contacts created during live testing.

## Package Quality Gates

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_salesforce
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_salesforce/test --no-deps-check
```
