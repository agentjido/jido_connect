# Google Slides Connector Guidance

- Keep product-specific Slides DSL, handlers, schemas, normalized structs, and
  tests in this package. Shared Google OAuth, transport, scope, pagination, and
  account helpers belong in `jido_connect_google`.
- Keep Google Slides v1 presentation, page, and batch update concerns separated
  into focused client modules as they are added.
- Treat presentation content, page elements, images, and speaker notes as
  provider-specific contracts. Do not add a generic presentation-content DSL to
  `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
