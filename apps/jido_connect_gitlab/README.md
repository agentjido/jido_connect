# Jido Connect GitLab

`jido_connect_gitlab` is the GitLab provider package for `jido_connect`.

It includes:

- `Jido.Connect.GitLab`, a Spark-authored provider that compiles into Jido tools
- OAuth2 helpers in `Jido.Connect.GitLab.OAuth`
- Scope resolver in `Jido.Connect.GitLab.ScopeResolver`

The Spark DSL declaration lives in `lib/jido_connect/gitlab.ex`.

## Status

This is an **experimental** scaffold. Action fragments, trigger fragments,
normalized structs, and webhook support will be added in subsequent waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_gitlab, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for GitLab:

- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
  with PKCE against the GitLab authorization server. Grants scoped
  access on behalf of a GitLab user. Supports refresh and revocation.

- **PAT** (`:pat`): GitLab personal access token passed as a Bearer token.
  Recommended for server-to-server integrations, development, and CI.

## GitLab API Scopes

| Scope | Description |
|---|---|
| `api` | Full access to the API |
| `read_api` | Read-only access to the API |
| `read_repository` | Read-only access to repositories |
| `write_repository` | Write access to repositories |

Read scopes are included in both default scope sets. The `api` and
`write_repository` scopes are optional for the OAuth2 profile and should
be requested only when mutation actions are needed.

## Self-Hosted GitLab

The OAuth helpers support self-hosted GitLab instances. Override the
default URLs via options:

```elixir
OAuth.authorize_url(
  client_id: "client",
  redirect_uri: "https://demo.test/callback",
  state: "state",
  authorize_url: "https://gitlab.example.com/oauth/authorize"
)

OAuth.exchange_code("code",
  client_id: "client",
  client_secret: "secret",
  redirect_uri: "https://demo.test/callback",
  token_url: "https://gitlab.example.com/oauth/token"
)
```

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
generated plugin surface, and OAuth helpers through injected fake
clients and does **not** call live GitLab APIs.

### Environment Variables for Live Testing

```sh
export GITLAB_CLIENT_ID="your-client-id"
export GITLAB_CLIENT_SECRET="your-client-secret"
# Never commit these values to version control.
```

## Package Quality Gates

The GitLab package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_gitlab
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_gitlab/test --no-deps-check
```
