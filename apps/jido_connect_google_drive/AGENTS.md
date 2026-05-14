# Google Drive Connector Guidance

- Keep Drive scopes narrow. Prefer `drive.metadata.readonly`, `drive.readonly`, and `drive.file` before broad Drive scopes.
- Normalize Drive API payloads into package structs before returning them from handlers.
- Keep Drive watch/webhook behavior provider-specific. Model Google channel ids, resource ids, `X-Goog-*` headers, and renewal semantics in this package.
- Keep file content bytes out of normalized metadata structs unless a specific action explicitly downloads or exports content.
- Destructive file and permission mutations must carry risk or confirmation metadata in the DSL.
