# Jido Connect Google Tasks

Google Tasks provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Tasks-specific DSL,
handlers, schemas, normalized structs, and tests package-local.

## Actions

### Task list actions

- `google.tasks.tasklist.list`
- `google.tasks.tasklist.get`
- `google.tasks.tasklist.create`
- `google.tasks.tasklist.update`
- `google.tasks.tasklist.delete`

### Task actions

- `google.tasks.task.list`
- `google.tasks.task.get`
- `google.tasks.task.create`
- `google.tasks.task.update`
- `google.tasks.task.delete`
- `google.tasks.task.clear`
- `google.tasks.task.move`

## Triggers

- `google.tasks.task.changed`

The task-change poller uses `updatedMin` timestamp checkpoints. On the first
poll it takes a full snapshot to capture an initial checkpoint. Subsequent
polls emit signals for each task modified at or after the checkpoint.
Deduplication by `task_id + updated` prevents double-emission.

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

## Scope Matrix

The Tasks scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| `google.tasks.tasklist.list` | `tasks.readonly` | Read-only access |
| `google.tasks.tasklist.get` | `tasks.readonly` | Read-only access |
| `google.tasks.task.list` | `tasks.readonly` | Read-only access |
| `google.tasks.task.get` | `tasks.readonly` | Read-only access |
| `google.tasks.tasklist.create` | `tasks` | Write required |
| `google.tasks.tasklist.update` | `tasks` | Write required |
| `google.tasks.tasklist.delete` | `tasks` | Write required |
| `google.tasks.task.create` | `tasks` | Write required |
| `google.tasks.task.update` | `tasks` | Write required |
| `google.tasks.task.delete` | `tasks` | Write required |
| `google.tasks.task.clear` | `tasks` | Write required |
| `google.tasks.task.move` | `tasks` | Write required |

Write operations always require `tasks`. The readonly scope never satisfies
write operations.

## Data Classification

Task actions declare data classifications following the Jido Connect taxonomy.
Classifications are documented as actions are added.

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

## Tool Availability

Generated plugin availability covers every Tasks action and trigger.
Hosts can pass a durable connection plus optional allow lists to see
`:available`, `:missing_scopes`, `:connection_required`, or
`:disabled_by_policy` per tool:

```elixir
Jido.Connect.Google.Tasks.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.tasks.task.list"],
  allowed_triggers: ["google.tasks.task.changed"]
})
```

## Generated Modules

- **Action modules**: `Jido.Connect.Google.Tasks.Actions.ListTaskLists`,
  `GetTaskList`, `CreateTaskList`, `UpdateTaskList`, `DeleteTaskList`,
  `ListTasks`, `GetTask`, `CreateTask`, `UpdateTask`, `DeleteTask`,
  `ClearTasks`, `MoveTask`
- **Sensor module**: `Jido.Connect.Google.Tasks.Sensors.TaskChanged`
- **Plugin module**: `Jido.Connect.Google.Tasks.Plugin`
- **Manifest**: available via `Tasks.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.

## Live-Test Guidance

The offline test suite exercises every action, trigger, scope, pack, and
naming convention through injected fake clients and does **not** call live
Google APIs. When you need to validate against a real Google Tasks account:

1. **Use a dedicated test Google account** — never personal or production
   accounts. Create a separate Google Workspace or Gmail account for testing.

2. **Use the OAuth playground or a staging app** — configure a Google Cloud
   project with Tasks API enabled, then authorize through the OAuth
   authorization-code flow to obtain real tokens.

3. **Scope grants to the least-privilege pack** — start with
   `:google_tasks_readonly` and only escalate to `:google_tasks_editor` as the
   test scenario demands. Verify that scope-restricted connections correctly
   report `:missing_scopes`.

4. **Exercise the full lifecycle** — create a task list, create tasks within
   it, update and move tasks, list tasks, then clean up by deleting all test
   tasks and task lists.

5. **Verify poll trigger checkpoint semantics** — confirm that the first poll
   captures an initial checkpoint without emitting signals, and that
   subsequent polls emit signals only for tasks modified after the checkpoint.

6. **Do not hardcode tokens** — store OAuth tokens in environment variables or
   a secrets manager. Never commit access tokens, refresh tokens, or client
   secrets to version control.

7. **Clean up** — delete all test task lists and tasks after each live test
   run to avoid accumulating stale resources in the test account.
