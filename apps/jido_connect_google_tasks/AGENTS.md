# Google Tasks Connector Guidance

- Keep product-specific Tasks DSL, handlers, schemas, normalized structs, and
  tests in this package. Shared Google OAuth, transport, scope, pagination, and
  account helpers belong in `jido_connect_google`.
- Keep Google Tasks v1 task list and task concerns separated into focused client
  modules as they are added.
- Treat task list, task, link, and mutation result structs as provider-specific
  contracts. Do not add a generic task DSL to `jido_connect` core.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
