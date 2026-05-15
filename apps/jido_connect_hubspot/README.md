# Jido Connect HubSpot

HubSpot CRM provider package for Jido Connect.

This package provides a HubSpot integration for Jido Connect, supporting
contacts, companies, deals, and tickets via the HubSpot CRM API.

## Status

This is an **experimental** scaffold. Action fragments, trigger fragments,
normalized structs, and catalog packs will be added in subsequent waves.

## Auth Profiles

The provider supports two authentication profiles:

- **Private app token** (`:private_app_token`): HubSpot private app access
  token passed as a Bearer token. Recommended for server-to-server integrations,
  development, and CI.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE. Grants scoped access on behalf of a HubSpot user.

## HubSpot Scopes

The provider declares HubSpot CRM scopes for contacts, companies, deals,
and tickets:

| Scope | Read | Write |
|---|---|---|
| Contacts | `crm.objects.contacts.read` | `crm.objects.contacts.write` |
| Companies | `crm.objects.companies.read` | `crm.objects.companies.write` |
| Deals | `crm.objects.deals.read` | `crm.objects.deals.write` |
| Tickets | `crm.objects.tickets.read` | `crm.objects.tickets.write` |

Read scopes are included in both default scope sets. Write scopes are
optional and should be requested only when mutation actions are needed.

## API Boundaries

All HubSpot API traffic uses
`Jido.Connect.HubSpot.Client.Transport.api_request/2`, which builds bearer
requests against the configurable HubSpot CRM API base URL.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
generated plugin surface through injected fake clients and does **not** call
live HubSpot APIs. When you need to validate against a real HubSpot account:

1. **Use a dedicated test HubSpot account** — never personal or production
   accounts. Create a separate HubSpot developer test account for testing.

2. **Use a private app token for CI and development** — generate a private
   app access token from the HubSpot app settings. Store it in an environment
   variable, never in version control.

3. **Do not hardcode tokens** — store access tokens and refresh tokens in
   environment variables or a secrets manager. Never commit access tokens,
   refresh tokens, or client secrets to version control.

## Package Quality Gates

The HubSpot package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_hubspot
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_hubspot/test --no-deps-check
```
