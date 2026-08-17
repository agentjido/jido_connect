# Jido Connect Things

`jido_connect_things` is an experimental provider for the Wayfinder Things
Task Conformance V1 surface. It has these read groups:

- Task list, get, and search across Inbox, Today, Evening, Anytime, Someday,
  Upcoming, Logbook, and Trash.
- Project, heading, area, and tag lists.

It has guarded actions for create, title or full-note update, schedule,
deadline, tags, container move, complete, cancel, reopen, Trash, and restore.

## Unofficial protocol warning

Things Cloud does not publish or support the write protocol used by this
package. The schema-301 wire format comes from observed client behavior. A
provider change can cause data loss or corruption.

The package fails closed unless it sees the reviewed endpoint, selected
account, active account state, schema 301, complete current state, and exact
prepared history head. It does not include recurrence, reminder, checklist,
project, heading, area, or tag writes. It also does not include direct delete,
tombstone, batch, raw position, raw wire, or account administration actions.

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

A full-note replacement on a non-empty note also needs `high_risk?: true`.
Trash needs both `high_risk?: true` and `destructive?: true`. The Trash action
also uses the core destructive action type and always requires confirmation.

## Optional host read adapter

A host can pass `:read_adapter` for list output or prepare-time update
eligibility from a local projection. The adapter must bind its result to the
current provider head. Commit always reads fresh provider history itself before
it sends the write.

## Catalog packs

- `things_inbox_reader` contains all V1 read actions.
- `things_inbox_editor` adds all V1 guarded Task6 write actions.

Both packs are storage-free. They do not contain raw wire, direct delete, or
tombstone tools.

## Wayfinder action migration

| Wayfinder action | Provider action |
| --- | --- |
| `tasks.item.list` | `things.todo.list` |
| `tasks.todo.create` | `things.todo.create` |
| `tasks.todo.update` | `things.todo.update` |
| Task schedule intent | `things.todo.schedule` |
| Task deadline intent | `things.todo.deadline.set` or `.clear` |
| Task tag intent | `things.todo.tags.set` |
| Task container intent | `things.todo.move` |
| Task lifecycle intent | `things.todo.complete`, `.cancel`, or `.reopen` |
| Task Trash intent | `things.todo.trash` or `.restore` |

See [CONFORMANCE.md](CONFORMANCE.md) for the action matrix, safety boundary,
and offline evidence.
