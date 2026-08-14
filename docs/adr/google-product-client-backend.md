# ADR: Google Product Client Backend

## Status

Accepted

## Context

Milestone 2 introduces a family of Google connectors. The shared Google
foundation is intentionally small and provider-neutral within the Google
ecosystem. Product packages still need HTTP clients for Sheets, Gmail, Drive,
Calendar, Contacts, Meet, Analytics, and Search Console.

The first evaluation slice compared one Sheets read operation:

- Operation: `google.sheets.spreadsheet.get`
- Generated backend: `google_api_sheets`
- Handwritten backend: Req client using `Jido.Connect.Google.Transport`
- Output: normalized spreadsheet map in a test-only facade

## Options

- Use generated `google_api_*` clients behind Jido facades.
- Use handwritten Req clients using `Jido.Connect.Google.Transport`.

## Decision

Use handwritten Req clients for first-wave Google product connectors.

Use generated `google_api_*` packages as external implementation references
only. Do not keep them as package dependencies unless a later product decision
shows that their endpoint coverage is worth the runtime and test stack.

## Rationale

The generated `google_api_sheets` client worked behind a facade, but it added
`google_gax`, `tesla`, and `poison`, compiled hundreds of generated modules, and
required a second test/mocking stack through `Tesla.Mock`. It also emitted
dependency compile warnings from generated/Tesla code. Provider errors still had
to be wrapped to preserve Jido's sanitized Splode error contract.

The handwritten Req slice used existing `CredentialLease` access-token handling,
`Jido.Connect.Google.Transport`, `Req.Test`, and the same sanitized provider
error boundary used by the rest of `jido_connect`. It required more endpoint
code, but the code shape is smaller and easier to implement one Beadwork story
at a time.

## Consequences

- First-wave product packages should add small API-area clients, not generated
  Google runtime dependencies.
- Generated clients can remain useful as implementation references for endpoint
  parameters and response models.
- If a later connector has a very large endpoint surface, create a focused ADR
  before adding a generated runtime dependency.
- Product package tests should assert method, path, query, body, sanitized
  errors, and normalized Zoi structs through Req fixtures.

## Follow-Up

- Completed for 0.8.0: remove the test-only `google_api_sheets` spike and its
  `google_gax`, Tesla, and Poison dependencies.
- Use this decision for the initial `jido_connect_google_sheets` package.
