# Jido Connect Calendly

Calendly provider package for Jido Connect.

This package provides a Calendly integration for Jido Connect. The scaffold
establishes the umbrella app, provider module, OAuth/PAT auth profiles,
transport boundary, and generated plugin tests. Action capabilities, triggers,
and catalog packs will be added in subsequent steps.

## Auth Profiles

The provider supports two authentication profiles:

- **Personal Access Token** (`:personal_access_token`): Calendly PAT passed as
  a Bearer token. Recommended for development and CI.
- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE against Calendly's identity provider.

## OAuth Scopes

The provider declares Calendly OAuth scopes:

- `view` — read access to user, event type, and scheduling data
- `edit` — write access to event types and invitees
- `webhook` — manage webhook subscriptions

Read-only operations should use the `view` scope when possible. Mutations
require `edit` and webhook management requires the `webhook` scope.

## API Boundaries

All Calendly API traffic uses
`Jido.Connect.Calendly.Client.Transport.api_request/2`, which builds bearer
requests against the configurable Calendly API v2 base URL
(`https://api.calendly.com`).

## Catalog Packs

`Jido.Connect.Calendly.catalog_packs/0` returns storage-free catalog packs that
hosts can pass to the catalog boundary. The scaffold provides a reader pack;
additional packs will be added as capabilities are implemented.

## Generated Modules

- **Plugin module**: `Jido.Connect.Calendly.Plugin`
- **Manifest**: available via `Calendly.jido_connect_manifest/0`

## Package Quality Gates

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_calendly
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_calendly/test --no-deps-check
```
