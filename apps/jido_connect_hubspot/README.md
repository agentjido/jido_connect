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

## Catalog Packs

The provider ships two curated catalog packs for scoping tool discovery
and invocation:

| Pack | Risk | Description |
|------|------|-------------|
| `:hubspot_reader` | read | Contact, company, and deal queries |
| `:hubspot_sales_editor` | write | Reader + contact/deal mutations and notes |

Triggers are subscribed to independently and are not listed in packs.

### Scope Matrix

Each action maps to the narrowest set of HubSpot CRM scopes required:

| Operation | Required Scopes |
|-----------|----------------|
| `hubspot.contacts.contact.get` | `crm.objects.contacts.read` |
| `hubspot.contacts.contact.list` | `crm.objects.contacts.read` |
| `hubspot.contacts.contact.search` | `crm.objects.contacts.read` |
| `hubspot.contacts.contact.create` | `crm.objects.contacts.write` |
| `hubspot.contacts.contact.update` | `crm.objects.contacts.write` |
| `hubspot.companies.company.get` | `crm.objects.companies.read` |
| `hubspot.companies.company.list` | `crm.objects.companies.read` |
| `hubspot.companies.company.search` | `crm.objects.companies.read` |
| `hubspot.deals.deal.get` | `crm.objects.deals.read` |
| `hubspot.deals.deal.list` | `crm.objects.deals.read` |
| `hubspot.deals.deal.search` | `crm.objects.deals.read` |
| `hubspot.deals.deal.create` | `crm.objects.deals.write` |
| `hubspot.deals.deal.update` | `crm.objects.deals.write` |
| `hubspot.notes.note.create` | `crm.objects.contacts.write`, `crm.objects.deals.write` |

### Privacy Classification

| Operation | Classification | Risk | Confirmation |
|-----------|---------------|------|-------------|
| Contact get/list/search | `personal_data` | read | none |
| Contact create/update | `personal_data` | write | required_for_ai |
| Company get/list/search | `workspace_metadata` | read | none |
| Deal get/list/search | `workspace_metadata` | read | none |
| Deal create/update | `workspace_metadata` | write | required_for_ai |
| Note create | `workspace_content` | write | required_for_ai |

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
generated plugin surface through injected fake clients and does **not** call
live HubSpot APIs. ### Offline Tests

The offline test suite exercises provider metadata, auth profiles, generated
plugin surface, catalog packs, scope matrix, and privacy classification
through injected fake clients and does **not** call live HubSpot APIs.

### Running Against a Live HubSpot Account

When you need to validate against a real HubSpot account:

1. **Use a dedicated test HubSpot account** — never personal or production
   accounts. Create a separate HubSpot developer test account for testing.

2. **Use a private app token for CI and development** — generate a private
   app access token from the HubSpot app settings. Store it in an environment
   variable, never in version control.

3. **Do not hardcode tokens** — store access tokens and refresh tokens in
   environment variables or a secrets manager. Never commit access tokens,
   refresh tokens, or client secrets to version control.

4. **Start with the reader pack** — validate read-only actions first using
   `HubSpot.catalog_packs()` with the `:hubspot_reader` pack. This requires
   only read scopes and avoids accidental data mutation.

5. **Upgrade to sales_editor for write tests** — once read actions pass,
   switch to the `:hubspot_sales_editor` pack to exercise contact/deal
   creation and note writing against your test account.

6. **Verify scope enforcement** — connect with read-only scopes and confirm
   that write actions return `{:error, %AuthError{reason: :missing_scopes}}`
   before testing with full scopes.

7. **Clean up test data** — remove contacts, deals, and notes created during
   live testing from your HubSpot test account after each session.

### Environment Variables for Live Testing

```sh
export HUBSPOT_PRIVATE_APP_TOKEN="pat-xxx-your-token-here"
# Never commit this value to version control.
```

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

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
