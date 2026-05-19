# CHANGELOG

All notable changes to `jido_connect_microsoft_onedrive` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-19

### Added

- Initial scaffold: integration DSL, auth profile reuse from the Microsoft
  foundation package, scope resolver, catalog pack shell, and generated module
  tests.
- Action catalog listing drive item read, write, and delete actions.
  Handlers return `{:error, :not_implemented}` until full drive item actions
  are added.
- Scope resolver with least-privilege resolution: reads accept Files.Read.All,
  Files.ReadWrite, and Files.ReadWrite.All; writes accept Files.ReadWrite.All.
- Privacy boundary module classifying storage content and personal data fields.
  Raw content keys (`content`, `@content.downloadUrl`) are filtered during
  normalization.
- Catalog packs: `:microsoft_onedrive_metadata` (read-only list metadata),
  `:microsoft_onedrive_triage` (adds item detail reads),
  `:microsoft_onedrive_write` (adds item create, update, and upload),
  `:microsoft_onedrive_destructive` (adds item delete).
- Normalizer for `driveItem` and `drive` payloads with paging envelope
  support. Download URLs and file content are excluded from normalized output.
- Env-gated live smoke test shell gated on `MICROSOFT_ACCESS_TOKEN` environment
  variable. Tests are skipped pending handler implementations.
