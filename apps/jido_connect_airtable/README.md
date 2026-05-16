# Jido Connect Airtable

Airtable provider package for Jido Connect.

This package provides an Airtable integration for Jido Connect, supporting
bases, tables, and records via the Airtable REST API.

## Status

This is an **experimental** scaffold. Action fragments, trigger fragments,
normalized structs, and catalog packs will be expanded in subsequent waves.

## Auth Profiles

The provider supports two authentication profiles:

- **Personal Access Token** (`:personal_access_token`): Airtable PAT passed
  as a Bearer token. Recommended for server-to-server integrations,
  development, and CI.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE. Grants scoped access on behalf of an Airtable user.

## Airtable Scopes

The provider declares Airtable API scopes for data and schema access:

| Scope | Description |
|---|---|
| `data.records:read` | Read records from tables |
| `data.records:write` | Create, update, and delete records |
| `schema.bases:read` | Read base and table schema |
| `schema.bases:write` | Modify base and table schema |
| `webhook:manage` | Create and manage webhooks |

Read scopes (`data.records:read`, `schema.bases:read`) are included in both
default scope sets. Write scopes are optional and should be requested only
when mutation actions are needed.

## API Boundaries

All Airtable API traffic uses
`Jido.Connect.Airtable.Client.Transport.api_request/2`, which builds bearer
requests against the configurable Airtable API base URL.

## Catalog Packs

The provider ships curated catalog packs for scoping tool discovery
and invocation:

| Pack | Risk | Description |
|------|------|-------------|
| `:airtable_reader` | read | Base schema and record queries |
| `:airtable_editor` | write | Reader + record create, update, delete |

Triggers are subscribed to independently and are not listed in packs.

### Scope Matrix

Each action maps to the narrowest set of Airtable API scopes required:

| Operation | Required Scopes |
|-----------|----------------|
| `airtable.bases.list` | `schema.bases:read` |
| `airtable.bases.get` | `schema.bases:read` |
| `airtable.records.list` | `data.records:read` |
| `airtable.records.get` | `data.records:read` |
| `airtable.records.create` | `data.records:write` |
| `airtable.records.update` | `data.records:write` |
| `airtable.records.delete` | `data.records:write` |

### Privacy Classification

| Operation | Classification | Risk | Confirmation |
|-----------|---------------|------|-------------|
| Bases list/get | `workspace_metadata` | read | none |
| Records list/get | `workspace_content` | read | none |
| Records create/update | `workspace_content` | write | required_for_ai |
| Records delete | `workspace_content` | write | required_for_ai |

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
generated plugin surface through injected fake clients and does **not** call
live Airtable APIs.

### Offline Tests

The offline test suite exercises provider metadata, auth profiles, generated
plugin surface, catalog packs, scope matrix, and privacy classification
through injected fake clients and does **not** call live Airtable APIs.

### Running Against a Live Airtable Account

When you need to validate against a real Airtable account:

1. **Use a dedicated test base** — never personal or production bases.
   Create a separate Airtable base for testing.

2. **Use a personal access token for CI and development** — generate a PAT
   from the Airtable developer hub. Store it in an environment variable,
   never in version control.

3. **Do not hardcode tokens** — store access tokens and refresh tokens in
   environment variables or a secrets manager. Never commit access tokens,
   refresh tokens, or client secrets to version control.

4. **Start with the reader pack** — validate read-only actions first using
   the `:airtable_reader` pack. This requires only read scopes and avoids
   accidental data mutation.

5. **Upgrade to editor for write tests** — once read actions pass, switch
   to the `:airtable_editor` pack to exercise record creation and updates
   against your test base.

6. **Verify scope enforcement** — connect with read-only scopes and confirm
   that write actions return `{:error, %AuthError{reason: :missing_scopes}}`
   before testing with full scopes.

7. **Clean up test data** — remove records created during live testing from
   your Airtable test base after each session.

### Environment Variables for Live Testing

```sh
export AIRTABLE_PERSONAL_ACCESS_TOKEN="patXXX-your-token-here"
# Never commit this value to version control.
```

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Airtable package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_airtable
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_airtable/test --no-deps-check
```
