# Things Connector Guidance

- Treat the Things Cloud write protocol as unofficial and experimental.
- Fail closed when the endpoint, account, schema, history head, or plan changes.
- Keep all write bodies private. Public plans can contain only safe previews,
  stable IDs, and hashes.
- Keep writes inside the documented Task Conformance V1 boundary. Do not add
  recurrence, reminder, checklist, structural entity, direct delete,
  tombstone, batch, raw position, or raw wire actions.
- Use only fake transports and fixtures in tests. Never make a live write.
