# Google Generated-Client Spike Harness

This document is the evaluation harness for deciding whether Google product
connectors should use generated `google_api_*` packages at runtime, use them as
implementation references only, or avoid them in favor of small handwritten Req
clients behind Jido facades.

The production public API must not expose generated Google client modules
directly. Product packages should expose Jido Connect DSL operations, provider
handlers, normalized Zoi structs, and small public facades regardless of the
chosen HTTP backend.

## Candidate Backends

Evaluate each product connector against two implementation styles:

- Generated client behind a Jido facade, for example `google_api_sheets`.
- Handwritten Req client using `Jido.Connect.Google.Transport`.

The first concrete slice should be a single Sheets read operation:

- Operation: `google.sheets.spreadsheet.get`
- Input: `spreadsheet_id`, optional `ranges`, optional `include_grid_data`
- Output: normalized `Google.Sheets.Spreadsheet`
- Auth profile: `:user`
- Scopes: `https://www.googleapis.com/auth/spreadsheets.readonly`

## Required Spike Evidence

Each backend must show:

- How request auth is injected from `CredentialLease`.
- How request path/query/body is visible in tests.
- How provider HTTP/API errors become sanitized `Jido.Connect.Error.ProviderError`.
- How malformed success payloads become sanitized provider errors.
- How normalized output avoids leaking raw provider payloads by default.
- How Req options or generated-client transport options can be injected in tests.
- How pagination would be handled for list APIs.
- How much dependency weight and compile-time surface the backend adds.

## Generated Client Checklist

For a generated `google_api_*` package, capture:

- Package name and version.
- Transitive HTTP stack, especially whether it uses Tesla, Finch, Hackney, or another adapter.
- Whether the client accepts an externally supplied token or transport adapter cleanly.
- Whether request/response structs are stable enough to wrap.
- Whether errors expose raw provider response bodies.
- Whether test fixtures can assert method/path/query/body without live Google calls.
- Whether adding the dependency affects umbrella compile time materially.
- Whether docs/API names are discoverable enough for Codex/Beadwork implementation loops.

## Handwritten Req Checklist

For a handwritten Req implementation, capture:

- Endpoint path and query construction code size.
- Fixture/test code size.
- Normalized struct code size.
- Whether shared `Jido.Connect.Google.Transport` is sufficient.
- Whether provider-specific error handling needs more shared helpers.
- Whether the code is likely to stay readable as the action surface grows.

## Decision Matrix

Score each backend from 1 to 5. The first pass used the Sheets
`spreadsheets.get` operation and test-only facades in `jido_connect_google`.

| Criterion | Generated client | Handwritten Req | Notes |
| --- | --- | --- | --- |
| Auth/lease fit | 4 | 5 | Both accept short-lived access tokens. Req uses existing `CredentialLease` and `Jido.Connect.Google.Transport` directly. |
| Error hygiene | 3 | 5 | Generated client returns `Tesla.Env` errors that must be wrapped. Req reuses the existing sanitized provider error boundary. |
| Test ergonomics | 3 | 5 | Generated client can be tested with `Tesla.Mock`, but it adds another mocking stack. Req uses the existing `Req.Test` pattern. |
| Normalization control | 4 | 5 | Both require explicit normalization. Req keeps provider payload handling closer to the facade. |
| Dependency weight | 2 | 5 | `google_api_sheets` adds `google_gax`, `tesla`, and `poison`, and compiles hundreds of generated modules. |
| Endpoint coverage | 5 | 3 | Generated clients provide broad coverage. Handwritten clients require endpoint work per operation. |
| Codex taskability | 3 | 5 | Generated names are discoverable but noisy. Handwritten modules are smaller and match existing provider patterns. |
| Long-term maintainability | 3 | 5 | Generated clients are useful references, but production code should stay around small Jido-owned facades first. |

Final decision: use handwritten Req clients for first-wave Google product
connectors, backed by `Jido.Connect.Google.Transport`. The 0.8.0 release removes
the generated-client spike and its test-only dependencies. Use generated Google
packages as external references unless a later ADR approves one.

## ADR Template

Use this template for the final generated-client decision.

```markdown
# ADR: Google Product Client Backend

## Status

Proposed | Accepted | Rejected

## Context

Which product package and operation slice was evaluated?

## Options

- Generated `google_api_*` client behind Jido facade.
- Handwritten Req client using `Jido.Connect.Google.Transport`.

## Decision

Which backend should this product package use first?

## Consequences

- Dependency impact.
- Test strategy.
- Error handling strategy.
- Normalization strategy.
- Follow-up tasks.
```

## Acceptance For Closing The Spike

- One generated-client slice and one handwritten Req slice have been implemented
  or explicitly rejected with evidence.
- The decision matrix is filled in with notes.
- The ADR is committed next to this harness or linked from it.
- Product connector tasks use the selected backend without reopening the
  decision for every action.

See `docs/adr/google-product-client-backend.md` for the first decision.
