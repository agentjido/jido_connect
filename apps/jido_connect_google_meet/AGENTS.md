# Google Meet Connector Guidance

- Keep product-specific Meet DSL, handlers, schemas, and normalized structs in
  this package. Shared Google OAuth, transport, scope, pagination, and account
  helpers belong in `jido_connect_google`.
- Keep Meet space, conference record, recording, transcript, and trigger
  concerns separated into focused modules as they are added.
- Align scheduling-adjacent behavior with `jido_connect_google_calendar`, but
  keep Meet-specific scope and resource semantics in this package.
- Prefer handwritten Req clients using `Jido.Connect.Google.Transport` for the
  first implementation wave.
