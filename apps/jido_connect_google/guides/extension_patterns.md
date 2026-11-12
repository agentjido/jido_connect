# Google Extension Patterns

Use this guide when adding more actions or triggers to an existing Google
product package, or when starting another Google product connector.

## Package Layout

Keep shared Google concerns in `jido_connect_google`:

- OAuth and connection helpers
- shared transport/error mapping
- pagination and checkpoint helpers
- scope catalog helpers

Keep product API concerns in the product package:

- Spark DSL fragments grouped by capability
- handlers under `handlers/actions` or `handlers/triggers`
- API-area client modules under `client`
- params/response modules for request and response shaping
- normalized product structs and normalizers
- catalog packs for curated tool surfaces

Avoid adding catch-all client modules. A new API family should get a focused
client module such as `Client.Events`, `Client.Files`, or `Client.Values`.

## Adding Action Families

For a new action family:

1. Add or extend a Spark DSL fragment under `actions/`.
2. Use `google.<product>.<resource>.<verb>` IDs.
3. Declare label, description, resource, verb, data classification, effect,
   confirmation, scopes, and scope resolver in the DSL.
4. Put input validation that protects provider semantics in a handler module.
5. Put provider HTTP details in a focused client module.
6. Put query/body construction in `Client.Params` or a capability-specific
   params module.
7. Put response normalization in `Client.Response` and product normalizers.
8. Return normalized structs or body-safe maps from handlers.
9. Add the tool to only the catalog packs where it is safe by default.
10. Extend the product privacy, scope matrix, catalog, generated-module, and
    offline client tests.

Validation belongs closest to the boundary it protects. Handler validation is
for connector contract safety, such as recipient shape, event time ordering, or
permission constraints. Client params are for provider query/body translation.

## Dynamic Scopes

Scope resolvers should prefer narrow scopes and accept broader existing grants
when Google allows them. The resolver must be covered by a product scope matrix
with these rows when relevant:

- missing product grant fallback;
- narrow read grant;
- broad read or write grant that can satisfy reads;
- mutation grant;
- legacy accepted Google scopes.

Mutation actions should never silently downgrade to a read scope. Content-read
actions should use content scopes, not metadata-only scopes.

## Catalog Placement

Catalog packs are safety surfaces. When adding a tool:

- add read-only tools to reader/metadata packs only when they do not mutate or
  expose unexpected content;
- add common writes only to writer/scheduler/triage-style packs;
- exclude destructive, broad batch, permission-sharing, and external-send tools
  unless the pack is explicitly named for that risk;
- update `metadata.risk` or `metadata.excludes` so hosts can explain the pack.

## Adding Trigger Families

For a new trigger family:

1. Add a trigger DSL fragment under `triggers/`.
2. Declare `kind`, `checkpoint`, `dedupe`, data classification, scope resolver,
   config schema, and signal schema.
3. Keep poller state host-owned: accept a checkpoint, return the next
   checkpoint, and do not persist internally.
4. Initialize empty checkpoints without replaying existing provider history.
5. Drain all provider pages before returning.
6. Deduplicate signals using the DSL dedupe key.
7. Normalize expired or invalid checkpoints through
   `Jido.Connect.Google.Checkpoint`.
8. Add offline tests for initialization, page draining, dedupe, checkpoint
   advance, expired checkpoint reset guidance, and repeated-page-token reset
   guidance.

## Offline Fixtures

Prefer realistic JSON fixtures for provider payload shapes. Fixtures should
cover common success responses and edge cases such as missing optional fields,
pagination cursors, deleted/cancelled resources, permission principals, binary
content metadata, and provider error bodies.

Do not require live credentials or demos for package tests. Live checks should
remain a separate release-readiness activity.
