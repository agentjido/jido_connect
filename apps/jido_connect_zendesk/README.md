# Jido Connect Zendesk

`jido_connect_zendesk` is the Zendesk provider package for `jido_connect`.

It includes:

- `Jido.Connect.Zendesk`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:zendesk_reader`, `:zendesk_editor`)
- OAuth2 helpers in `Jido.Connect.Zendesk.OAuth`
- REST client helpers in `Jido.Connect.Zendesk.Client`
- Transport boundary in `Jido.Connect.Zendesk.Client.Transport`
- Response normalization in `Jido.Connect.Zendesk.Client.Normalizer`

The Spark DSL declaration lives in
`lib/jido_connect/zendesk.ex`. Provider handlers live under
`lib/jido_connect/zendesk/handlers/`.

## Status

This is an **experimental** scaffold. Ticket actions, trigger fragments,
normalized structs, and webhook support will be added in subsequent waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_zendesk, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Zendesk:

- **API token** (`:api_token`): Zendesk API token used with the email address
  via Basic authentication (`email/token:api_token`). Recommended for
  server-to-server integrations, development, and CI.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Zendesk authorization server. Grants scoped access on behalf of a Zendesk
  user.

## Zendesk Scopes

The provider declares Zendesk OAuth scopes:

| Scope | Description |
|---|---|
| `read` | Read tickets, users, and other resources |
| `write` | Create and update resources |
| `tickets:read` | Read tickets |
| `tickets:write` | Create and update tickets |
| `users:read` | Read user information |

Read scopes are included in both default scope sets. The `write` and
`tickets:write` scopes are optional for the OAuth2 profile and should be
requested only when mutation actions are needed.

## Actions

Ticket actions will be added in a subsequent wave.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Tools |
|---|---|
| `:zendesk_reader` | Read-only Zendesk queries |
| `:zendesk_editor` | Reader + write tools |

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("zendesk",
  modules: [Jido.Connect.Zendesk],
  packs: Jido.Connect.Zendesk.catalog_packs(),
  pack: :zendesk_reader
)

# Full editor access
Catalog.search_tools("zendesk",
  modules: [Jido.Connect.Zendesk],
  packs: Jido.Connect.Zendesk.catalog_packs(),
  pack: :zendesk_editor
)
```

## API Boundaries

All Zendesk API traffic uses
`Jido.Connect.Zendesk.Client.Transport.request/2`, which builds bearer
requests against the configurable Zendesk subdomain base URL.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, and catalog packs through injected fake clients
and does **not** call live Zendesk APIs.

### Environment Variables for Live Testing

```sh
export ZENDESK_API_TOKEN="your-api-token-here"
export ZENDESK_API_BASE_URL="https://your-subdomain.zendesk.com"
# Never commit these values to version control.
```

### Switching Mock / Live Clients

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Zendesk package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_zendesk
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_zendesk/test --no-deps-check
```
