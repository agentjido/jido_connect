# Things Connector Guidance

- Treat the Things Cloud write protocol as unofficial and experimental.
- Fail closed when the endpoint, account, schema, history head, or plan changes.
- Keep all write bodies private. Public plans can contain only safe previews,
  stable IDs, and hashes.
- Keep writes inside the documented Task Conformance V1 boundary. Do not add
  recurrence, reminder, checklist, structural entity, direct delete,
  tombstone, batch, raw position, or raw wire actions.
- Normal tests must use only fake transports and fixtures.
- The `:live_smoke` suite is the only live-test exception. It must be excluded
  by default, refuse CI, require the exact disposable account and all explicit
  acknowledgement gates, and stay inside the Task Conformance V1 boundary.
