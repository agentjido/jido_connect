# jido_connect_microsoft_onedrive

Microsoft OneDrive connector package for Jido Connect.

Builds on the shared `jido_connect_microsoft` foundation package for OAuth
profiles, Graph transport, pagination, scopes, and error normalization. This
package owns the Microsoft OneDrive integration DSL, action catalog, scope
resolver, privacy boundaries, catalog packs, and env-gated live smoke hooks.

## Installation

This package is part of the `jido_connect` umbrella and depends on
`jido_connect` and `jido_connect_microsoft`.

```elixir
def deps do
  [
    {:jido_connect_microsoft_onedrive, in_umbrella: true}
  ]
end
```

## Usage

```elixir
# Get the integration spec
spec = Jido.Connect.MicrosoftOnedrive.integration()

# List declared actions
spec.actions

# List catalog packs
Jido.Connect.MicrosoftOnedrive.catalog_packs()
```

## Architecture

- **Integration DSL** – Declares the `microsoft_onedrive` provider with
  drive and drive item actions, auth profiles reused from the Microsoft
  foundation, and catalog metadata.
- **Scope Resolver** – Maps action ids to required Microsoft Graph files
  scopes (`Files.Read`, `Files.Read.All`, `Files.ReadWrite`,
  `Files.ReadWrite.All`) with least-privilege resolution against existing
  grants.
- **Catalog Packs** – Curated tool surfaces (metadata, triage, write,
  destructive) for host policy enforcement.
- **Action Handlers** – Scaffold handlers return `{:error, :not_implemented}`
  until full drive item actions are implemented in follow-up tasks.
- **Normalizer** – Normalizes Microsoft Graph `driveItem` and `drive`
  payloads. Download URLs and file content are intentionally excluded from
  normalized structs.
- **Privacy Boundary** – File content, download URLs, and sharing metadata
  are classified and filtered. See "Privacy Boundary" below.

## Actions

### Read

| Action ID | Description | Classification | Scopes |
|---|---|---|---|
| `microsoft.onedrive.items.list` | List items in OneDrive root | personal_data | Files.Read |
| `microsoft.onedrive.item.get` | Get a single drive item by id | personal_data | Files.Read |
| `microsoft.onedrive.drive.get` | Get default drive metadata | personal_data | Files.Read |

### Write

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.onedrive.item.create` | Create a folder or file | personal_data | required_for_ai | Files.ReadWrite |
| `microsoft.onedrive.item.update` | Update drive item metadata | personal_data | required_for_ai | Files.ReadWrite |
| `microsoft.onedrive.item.upload` | Upload or replace a file | personal_data | required_for_ai | Files.ReadWrite |

### Destructive

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.onedrive.item.delete` | Permanently delete a drive item | personal_data | always | Files.ReadWrite |

## Scope Matrix

### Required Scopes by Action

| Action | Primary Scope | Accepted Alternatives |
|---|---|---|
| `items.list` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.get` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `drive.get` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.create` | Files.ReadWrite | Files.ReadWrite.All |
| `item.update` | Files.ReadWrite | Files.ReadWrite.All |
| `item.upload` | Files.ReadWrite | Files.ReadWrite.All |
| `item.delete` | Files.ReadWrite | Files.ReadWrite.All |

### Scope Hierarchy

```
Files.Read.All       ← satisfies → Files.Read
Files.ReadWrite      ← satisfies → Files.Read
Files.ReadWrite.All  ← satisfies → Files.ReadWrite
                     ← satisfies → Files.Read
```

## Privacy Boundary

OneDrive data can contain sensitive personal and organizational files. The
connector classifies item names, sizes, web URLs, and creator metadata as
storage content or personal data. Normalized structs intentionally avoid raw
file content and download URLs:

- **Raw content** and **@content.downloadUrl** are filtered during
  normalization.
- **Creator metadata** is limited to identity fields only.

The `Jido.Connect.MicrosoftOnedrive.Privacy` module documents which fields
carry storage content versus personal data and provides a `raw_content_key?/1`
guard for filtering sensitive keys.

## Catalog Packs

- **`:microsoft_onedrive_metadata`** — Read-only item list and drive metadata.
  No detail, mutation, or delete tools.
- **`:microsoft_onedrive_triage`** — Adds item get detail. Excludes create,
  update, upload, and delete tools.
- **`:microsoft_onedrive_write`** — Adds item create, update, and upload.
  Excludes delete tools.
- **`:microsoft_onedrive_destructive`** — Adds permanent item delete
  operations.

## License

MIT
