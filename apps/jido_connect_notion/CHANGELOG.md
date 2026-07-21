# Changelog

## 0.1.0

- Add the Notion provider package scaffold for Jido Connect.
- Add scope/capability matrix documentation (`docs/notion_scope_matrix.md`).
- Update README with action tables, catalog pack details, and change strategy note.
- Add read-only live smoke tests gated by `NOTION_TOKEN` env var.
- Document polling-based change detection strategy (Notion lacks generic webhooks).
