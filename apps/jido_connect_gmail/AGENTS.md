# Gmail Connector Guidance

- Keep Gmail scopes narrow and purpose-specific. Prefer `gmail.metadata` for mailbox metadata, `gmail.labels` for label definition CRUD, then `gmail.readonly`, `gmail.compose`, `gmail.send`, and `gmail.modify` only when required. Use `https://mail.google.com/` only for permanent message/thread deletes.
- Avoid leaking raw message bodies by default. Normalized message and thread structs should expose metadata, snippets, headers, labels, and payload summaries before content.
- Send, draft, and label mutations must carry risk or confirmation metadata in the DSL.
- Treat email addresses, subjects, snippets, and headers as personal or message content in action classifications.
