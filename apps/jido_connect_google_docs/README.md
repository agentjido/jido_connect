# Jido Connect Google Docs

Google Docs provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Docs-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Status

This scaffold declares the provider package, user OAuth profile, Docs
scope resolver, generated Jido plugin shell, and shared Google transport
boundaries. Document CRUD, batch update, catalog pack, and trigger work is
intentionally split into later implementation slices.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Docs product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/documents.readonly`
- `https://www.googleapis.com/auth/documents`

Read-only operations should use `documents.readonly` when possible. Document
creation and mutation should require `documents`.

## API Boundaries

- Google Docs v1 traffic should use
  `Jido.Connect.Google.Docs.Client.Transport.docs_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Tool Surface

No Docs actions or triggers are exposed by the scaffold yet. The generated
plugin and provider metadata are present so later tasks can add document get,
list, create, batch update, and catalog-pack action families without changing
package wiring.

## Tool Availability

Generated plugin availability is available from the scaffold and will report
one entry per generated action or trigger as those tools are added:

```elixir
Jido.Connect.Google.Docs.Plugin.tool_availability(%{connection: connection})
```
