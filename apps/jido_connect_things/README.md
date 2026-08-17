# Jido Connect Things

`jido_connect_things` is an experimental provider for a small Things Cloud
Inbox surface:

- `things.todo.list` lists open Inbox to-dos.
- `things.todo.create` creates one open Inbox to-do.
- `things.todo.update` changes only the title or notes of one open Inbox
  to-do.

## Unofficial protocol warning

Things Cloud does not publish or support the write protocol used by this
package. The schema-301 wire format comes from observed client behavior. A
provider change can cause data loss or corruption.

The package fails closed unless it sees the reviewed endpoint, selected account,
active account state, schema 301, and exact prepared history head. It does not
include delete, trash, completion, scheduling, project, area, tag, recurrence,
checklist, batch, or raw wire actions.

## Host-owned connection

The host owns the durable `Jido.Connect.Connection`. Put the selected account
email in `connection.subject.email` and the per-connection endpoint in
`connection.metadata.endpoint`. The reviewed production endpoint is:

```text
https://cloud.culturedcode.com
```

The host also owns credential storage. It mints a short-lived
`Jido.Connect.CredentialLease` with `email` and `password` fields for each call.
The provider does not persist either value. Client and lease `Inspect` output is
redacted.

Tests can inject a transport through the runtime `:transport` option. The
client still addresses the reviewed production endpoint, so the fake transport
must intercept that URL. Do not put a transport module in stored credential
data.

## Guarded writes

Direct write invocation is denied. Use the provider boundary:

```elixir
{:ok, prepared} =
  Jido.Connect.Things.prepare(
    "things.todo.create",
    %{title: "Review proposal", notes: "Read section 4"},
    context: context,
    credential_lease: lease
  )

{:ok, %{receipt: receipt}} =
  Jido.Connect.Things.commit(
    prepared,
    %{title: "Review proposal", notes: "Read section 4"},
    context: context,
    credential_lease: lease,
    commit?: true,
    execution_authorization: evidence,
    authorization_validator: validator
  )
```

Prepare reads the account, schema, provider head, and update target. It does not
send a write. Public prepared data contains only safe preview values, stable
IDs, and hashes. It does not contain a password, history key, or raw commit
body.

Commit verifies the account again, reads the provider head again, and checks an
update target again. It sends one commit request with retry disabled. A
transport failure after send returns `:sent_outcome_unknown`; callers must not
retry it. A successful acknowledgement is followed by a read verification.

Hosts still own global and provider write switches, exact action allowlists,
one-use execution claims, audit records, durable credentials, and local
projection refresh.

## Optional host read adapter

A host can pass `:read_adapter` for list output or prepare-time update
eligibility from a local projection. The adapter must bind its result to the
current provider head. Commit always reads fresh provider history itself before
it sends the write.

## Catalog packs

- `things_inbox_reader` contains `things.todo.list` only.
- `things_inbox_editor` adds `things.todo.create` and `things.todo.update`.

Both packs are storage-free. They do not contain raw wire or destructive tools.

## Wayfinder action migration

| Wayfinder action | Provider action |
| --- | --- |
| `tasks.item.list` | `things.todo.list` |
| `tasks.todo.create` | `things.todo.create` |
| `tasks.todo.update` | `things.todo.update` |

The list replacement is narrower: the first provider slice supports the Inbox
view only.
