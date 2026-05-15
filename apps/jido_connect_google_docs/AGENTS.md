# Google Docs Connector Guidance

- Keep product-specific Docs DSL, handlers, schemas, normalized structs, and
  tests in this package. Shared Google OAuth, transport, scope, pagination, and
  account helpers belong in `jido_connect_google`.
- Keep Google Docs v1 document, batch update, and revision concerns separated
  into focused client modules as they are added.
- Treat document content, styling, inline objects, and named ranges as
  provider-specific contracts. Do not add a generic document-content DSL to
  `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
