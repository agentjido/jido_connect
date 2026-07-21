# CHANGELOG

All notable changes to `jido_connect_microsoft_onedrive` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-19

### Added

- Initial scaffold: integration DSL, auth profile reuse from the Microsoft
  foundation package, scope resolver, catalog pack shell, and generated module
  tests.
- Action catalog listing drive item read, write, delete, sharing, and
  permission management actions. Handlers call Microsoft Graph endpoints
  through the shared transport module.
- Scope resolver with least-privilege resolution: reads accept Files.Read,
  Files.Read.All, Files.ReadWrite, and Files.ReadWrite.All; writes and
  destructive actions accept Files.ReadWrite and Files.ReadWrite.All.
- Privacy boundary module classifying storage content and personal data fields.
  Raw content keys (`content`, `@content.downloadUrl`) are filtered during
  normalization.
- Catalog packs: `:microsoft_onedrive_metadata` (read-only list metadata),
  `:microsoft_onedrive_triage` (adds item detail reads),
  `:microsoft_onedrive_write` (adds item create, update, and upload),
  `:microsoft_onedrive_destructive` (adds item delete),
  `:microsoft_onedrive_sharing` (adds sharing links and permission management),
  `:microsoft_onedrive_admin` (adds permission deletion).
- Normalizer for `driveItem`, `drive`, `folder`, `file`, `permission`,
  `sharingLink`, `thumbnail`, `deltaToken`, and `download` payloads with
  paging envelope support. Download URLs and file content are excluded from
  normalized output.
- Sharing actions: create sharing link with configurable link type, scope,
  password, and expiration.
- Permission actions: list, get, create (invite), and delete permissions on
  drive items.
- Delta action: track drive item changes using the Microsoft Graph delta
  endpoint with token-based incremental sync.
- Read-only live smoke hooks: list items, get item, get drive, list drives,
  search items, and delta endpoint. Gated on `MICROSOFT_ACCESS_TOKEN`.
- Destructive live smoke hooks: create/delete folder, create/delete sharing
  link. Gated on `MICROSOFT_LIVE_DESTRUCTIVE`.
- Fixture placeholders in root `.env.example`: `MICROSOFT_ONEDRIVE_DRIVE_ID`,
  `MICROSOFT_ONEDRIVE_ITEM_ID`.
- Delta/watch design note (`docs/delta-watch-design.md`) covering polling,
  webhook subscription, and hybrid change-detection approaches.
- Comprehensive scope matrix covering all 16 actions with primary scopes and
  accepted alternatives.
