# Jido Connect Asana

`jido_connect_asana` is the Asana provider package for `jido_connect`.

It includes:

- `Jido.Connect.Asana`, a Spark-authored provider that compiles into Jido tools
- Catalog packs for scoped tool discovery (`:asana_reader`, `:asana_editor`)

The Spark DSL declaration lives in
`lib/jido_connect/asana.ex`.

## Status

This is an **experimental** scaffold package. Action fragments, normalized
structs, client transport, and action handlers will be added in subsequent
waves.

## Installation

```elixir
def deps do
  [
    {:jido_connect_asana, "~> 0.1.0"}
  ]
end
```

## Auth Profiles

The provider supports two authentication profiles for Asana:

- **Personal access token** (`:pat`): Asana personal access token sent via the
  `Authorization: Bearer <token>` header. Created in the Asana developer
  console under "My app settings". Recommended for server-to-server
  integrations, development, and CI.

- **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
  Asana authorization server. Grants scoped access on behalf of an Asana user.
  Public integrations use this flow to request access to specific workspaces
  and projects.

## Asana Scopes

The provider declares Asana permission scopes:

| Scope | Description |
|---|---|
| `default` | Basic read access to workspaces, projects, and tasks |
| `read` | Extended read access |
| `write` | Create and update tasks, projects, and sections |

`default` and `read` scopes are included in the default scope set for both
auth profiles. The `write` scope should be requested only when mutation actions
are needed.

## Actions

Action fragments have not been added yet. Tool IDs will be populated as
actions are implemented in subsequent waves.

## Catalog Packs

The provider ships with curated catalog packs for scoped tool discovery:

| Pack | Risk | Tools |
|---|---|---|
| `:asana_reader` | read | _to be populated_ |
| `:asana_editor` | write | _to be populated_ |

Tool IDs are populated from action fragments.

Triggers are subscribed to independently and are not included in packs.

Use packs to restrict which tools are visible to a given surface:

```elixir
# Only expose read tools
Catalog.search_tools("asana",
  modules: [Jido.Connect.Asana],
  packs: Jido.Connect.Asana.catalog_packs(),
  pack: :asana_reader
)

# Full editor access
Catalog.search_tools("asana",
  modules: [Jido.Connect.Asana],
  packs: Jido.Connect.Asana.catalog_packs(),
  pack: :asana_editor
)
```

## API Boundaries

All Asana API traffic will use a dedicated transport boundary module. The base
URL defaults to `https://app.asana.com/api/1.0`.

## Environment Variables

| Variable | Description |
|---|---|
| `ASANA_TOKEN` | Personal access token for live smoke tests |
| `ASANA_WORKSPACE_ID` | Workspace ID fixture for live smoke tests |
| `ASANA_PROJECT_ID` | Project ID fixture for live smoke tests |

## Package Quality Gates

The Asana package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_asana
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_asana/test --no-deps-check
```
