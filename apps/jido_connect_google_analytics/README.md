# Jido Connect Google Analytics

Google Analytics provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Analytics-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Status

This scaffold declares the provider package, user OAuth profile, Analytics
scope resolver, generated Jido plugin shell, shared Google transport boundary,
and normalized Zoi-backed structs. Metadata, report, property discovery,
catalog pack, and trigger work is intentionally split into later Beadwork
tasks.

## Normalized Structs

- `Jido.Connect.Google.Analytics.Report`
- `Jido.Connect.Google.Analytics.Row`
- `Jido.Connect.Google.Analytics.Dimension`
- `Jido.Connect.Google.Analytics.Metric`
- `Jido.Connect.Google.Analytics.PropertySummary`

## OAuth Scopes

The provider declares the shared Google identity scopes plus Analytics product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/analytics.readonly`

## API Boundaries

- Analytics Data API traffic should use
  `Jido.Connect.Google.Analytics.Client.Transport.data_request/1`.
- Analytics Admin API traffic should use
  `Jido.Connect.Google.Analytics.Client.Transport.admin_request/1`.

Both request builders delegate to `Jido.Connect.Google.Transport` and are
configurable through application environment for tests.

## Tool Surface

No Analytics actions or triggers are exposed by the scaffold yet. The generated
plugin and provider metadata are present so later tasks can add metadata,
reporting, realtime, and property-discovery action families without changing
package wiring.

## Query Shape

Analytics report dimensions, metrics, filters, orderings, and limits are
provider-specific GA4 contracts. Keep those mappings in this package rather
than adding a generic query DSL to `jido_connect` core.

## Tool Availability

Generated plugin availability is available from the scaffold and will report
one entry per generated action or trigger as those tools are added:

```elixir
Jido.Connect.Google.Analytics.Plugin.tool_availability(%{connection: connection})
```
