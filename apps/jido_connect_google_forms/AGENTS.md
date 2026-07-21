# Google Forms Connector Guidance

- Keep product-specific Forms DSL, handlers, schemas, normalized structs, and
  tests in this package. Shared Google OAuth, transport, scope, pagination, and
  account helpers belong in `jido_connect_google`.
- Keep Google Forms v1 form, response, and batch update concerns separated
  into focused client modules as they are added.
- Treat form questions, responses, and grading as provider-specific contracts.
  Do not add a generic form-content DSL to `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
