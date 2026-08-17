# Things Connector Guidance

- Treat the Things Cloud write protocol as unofficial and experimental.
- Fail closed when the endpoint, account, schema, history head, or plan changes.
- Keep all write bodies private. Public plans can contain only safe previews,
  stable IDs, and hashes.
- Do not add delete, trash, completion, schedule, project, area, tag, recurrence,
  checklist, or raw wire actions to the first package slice.
- Use only fake transports and fixtures in tests. Never make a live write.
