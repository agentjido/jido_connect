# Google Analytics Connector Guidance

- Keep product-specific Analytics DSL, handlers, schemas, normalized structs,
  and tests in this package. Shared Google OAuth, transport, scope, pagination,
  and account helpers belong in `jido_connect_google`.
- Keep Analytics Data API and Analytics Admin API concerns separated into
  focused client modules as they are added.
- Treat GA4 report dimensions, metrics, filters, and orderings as
  provider-specific contracts. Do not add a generic report-query DSL to
  `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
