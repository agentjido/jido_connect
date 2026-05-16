# Jido Connect Jira

`jido_connect_jira` is the Jira provider package for `jido_connect`.

It includes:

- `Jido.Connect.Jira`, a Spark-authored provider that compiles into Jido tools
- Jira issue actions (get, search, create)
- OAuth2 helpers in `Jido.Connect.Jira.OAuth`
- REST client helpers in `Jido.Connect.Jira.Client`
- Transport boundary in `Jido.Connect.Jira.Client.Transport`
- Response normalization in `Jido.Connect.Jira.Client.Normalizer`

The Spark DSL declaration lives in
`lib/jido_connect/jira.ex`. Provider handlers live under
`lib/jido_connect/jira/handlers/`.

## Status

This is an **experimental** scaffold. Additional action fragments, trigger
fragments, normalized structs, and webhook support will be added in subsequent
waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_jira, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Atlassian Cloud:

- **API token** (`:api_token`): Jira personal access token or Atlassian
  API token passed as a Bearer token. Recommended for server-to-server
  integrations, development, and CI.

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
  with PKCE against the Atlassian authorization server. Grants scoped
  access on behalf of an Atlassian user.

## Atlassian Cloud Scopes

The provider declares Atlassian Cloud scopes for Jira:

| Scope | Description |
|---|---|
| `read:jira-work` | Read issues, projects, and filters |
| `write:jira-work` | Create and update issues |
| `read:jira-users` | Read user information |
| `read:jira-configuration` | Read project and configuration data |

Read scopes are included in both default scope sets. The `write:jira-work`
scope is optional for the OAuth2 profile and should be requested only when
mutation actions are needed.

## API Boundaries

All Jira API traffic uses
`Jido.Connect.Jira.Client.Transport.request/2`, which builds bearer
requests against the configurable Atlassian Cloud base URL.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
generated plugin surface through injected fake clients and does **not** call
live Jira APIs.

### Environment Variables for Live Testing

```sh
export JIRA_API_TOKEN="your-api-token-here"
export JIRA_API_BASE_URL="https://your-domain.atlassian.net"
# Never commit these values to version control.
```

The connector reads the token at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

The Jira package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_jira
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_jira/test --no-deps-check
```
