# Jido Connect Google Tasks

Google Tasks provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Tasks-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Actions

Task list and task actions are added in subsequent implementation tasks.
The scaffold establishes the provider module, scope resolver, catalog packs,
and baseline compile/test wiring.

## Auth Profiles

Tasks declares a user OAuth profile:

- `:user` for app-user OAuth authorization-code grants.

Every Tasks action advertises this profile through the Jido Connect action
catalog.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Tasks product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/tasks.readonly`
- `https://www.googleapis.com/auth/tasks`

Read-only operations should use `tasks.readonly` when possible. Task list and
task mutation should require `tasks`.

## Data Classification

Task actions declare data classifications following the Jido Connect taxonomy.
Classifications are documented as actions are added.

## Scope Matrix

The Tasks scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| read operations | `tasks.readonly` | Read-only access |
| write operations | `tasks` | Write required |

Write operations always require `tasks`. The readonly scope never satisfies
write operations.

## API Boundaries

- Google Tasks v1 traffic should use
  `Jido.Connect.Google.Tasks.Client.Transport.tasks_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Catalog Packs

- `:google_tasks_readonly` includes task list and task reads only.
- `:google_tasks_editor` adds task list and task creation, update, and
  deletion. Includes all Tasks tools.

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Tasks

# Search for read-only tools
Catalog.search_tools("tasks",
  modules: [Tasks],
  packs: Tasks.catalog_packs(),
  pack: :google_tasks_readonly
)
```

Pack delegates are available directly from the provider module:

```elixir
Tasks.catalog_packs()    # [readonly_pack, editor_pack]
Tasks.readonly_pack()    # :google_tasks_readonly
Tasks.editor_pack()      # :google_tasks_editor
```
