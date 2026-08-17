# Things Task Conformance V1

This package implements the bounded task surface from the Wayfinder Things
Conformance Specification, Draft 0.1, dated 2026-08-14. It does not claim to
implement the complete private Things Cloud API.

## Source baseline

- Things Cloud schema: 301
- Primary Go reference: `arthursoares/things-cloud-sdk` at
  `3e73320ed4f386f882a17a3645f4ec0a103418fe`
- Primary Rust reference: `evanpurkhiser/things3-cloud` at
  `1281f43bc677325968a6fdea242a5c39bb04d208`
- Product goal line: Wayfinder Things Conformance Specification, Draft 0.1

## Action coverage

| Capability | Provider actions | Risk |
| --- | --- | --- |
| Task query | `things.todo.list`, `.get`, `.search` | Read |
| References | `things.project.list`, `things.heading.list`, `things.area.list`, `things.tag.list` | Read |
| Create and text | `things.todo.create`, `.update` | Normal or high |
| Schedule | `things.todo.schedule` | Normal |
| Deadline | `things.todo.deadline.set`, `.clear` | Normal |
| Tags and containers | `things.todo.tags.set`, `.move` | Normal |
| Lifecycle | `things.todo.complete`, `.cancel`, `.reopen` | Normal |
| Trash | `things.todo.trash`, `.restore` | Destructive or normal |

The read model retains raw history and materializes Task6, ChecklistItem3,
Area3, Tag4, Tombstone2, and known legacy read families. Unknown data marks the
affected entity unsafe for writes but does not remove readable known state.

## Safety boundary

Every write uses prepare and commit. Prepare binds the account, schema,
history head, exact target state, canonical operation, body hash, preview, and
risk. Commit checks these values again, sends at most one POST with no retry,
and searches history for the exact operation and payload. Optional bounded
verification polling repeats only this safe history read. It never repeats the
POST.

Production serialization rejects recurrence, reminder, checklist, structural
entity, direct delete, tombstone, batch, raw position, legacy entity, and raw
wire writes. Complete private notes and request bodies do not enter public
previews.

## Offline evidence

- `state_test.exs`: entity folds, note deltas, null clears, deletes,
  tombstones, and full versus incremental replay.
- `query_test.exs`: views, filters, exact and prefix lookup, relations, and
  checklist output.
- `change_planner_test.exs`: schedule table, destinations, risk, lifecycle,
  Trash, restore, and planner rejection cases.
- `write_wire_test.exs`: canonical schema-301 shapes, stable hashes, sparse
  changes, and serializer exclusions.
- `runtime_test.exs`: fresh-head checks, guarded prepare and commit, one POST,
  no retry, exact and delayed verification, risk gates, delivery certainty,
  and redaction.
- `identifier_test.exs`: canonical 16-byte Base58 identifier properties.

All normal tests use fake transports. They do not call Things Cloud. The
excluded `:live_smoke` suite is the only live-test exception.

## External acceptance

The local `:live_smoke` suite runs a complete disposable-account cycle through
public provider actions. It refuses CI and requires the exact test account and
four acknowledgement gates. The cycle passed against Things Cloud schema 301
on 2026-08-17. It covered all V1 read groups and all guarded Task6 writes.

Official Things app acceptance is still host release evidence. A host must
complete this evidence before it enables unofficial writes for a real account.
