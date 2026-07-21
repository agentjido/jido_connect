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

### Searching Tools

```elixir
alias Jido.Connect.MicrosoftOnedrive

# Search for tools matching "onedrive" within the triage pack
Jido.Connect.Catalog.search_tools("onedrive",
  modules: [MicrosoftOnedrive],
  packs: MicrosoftOnedrive.catalog_packs(),
  pack: :microsoft_onedrive_triage
)
```

### Describing a Single Tool

```elixir
alias Jido.Connect.MicrosoftOnedrive

{:ok, descriptor} =
  Jido.Connect.Catalog.describe_tool("microsoft.onedrive.items.list",
    modules: [MicrosoftOnedrive],
    packs: MicrosoftOnedrive.catalog_packs(),
    pack: :microsoft_onedrive_metadata
  )

descriptor.tool.id
#=> "microsoft.onedrive.items.list"
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
  destructive, sharing, admin) for host policy enforcement.
- **Action Handlers** – Each handler calls Microsoft Graph endpoints through
  the shared `Jido.Connect.Microsoft.Transport` module and normalizes
  responses through the package normalizer.
- **Normalizer** – Normalizes Microsoft Graph `driveItem`, `drive`,
  `permission`, and `sharingLink` payloads. Download URLs and file content
  are intentionally excluded from normalized structs.
- **Privacy Boundary** – File content, download URLs, and sharing metadata
  are classified and filtered. See "Privacy Boundary" below.

## Actions

### Read

| Action ID | Description | Classification | Scopes |
|---|---|---|---|
| `microsoft.onedrive.items.list` | List items in OneDrive root or a folder | personal_data | Files.Read |
| `microsoft.onedrive.item.get` | Get a single drive item by id | personal_data | Files.Read |
| `microsoft.onedrive.drive.get` | Get default drive metadata | personal_data | Files.Read |
| `microsoft.onedrive.drives.list` | List drives available to the user | personal_data | Files.Read.All |
| `microsoft.onedrive.items.search` | Search items by query | personal_data | Files.Read |
| `microsoft.onedrive.item.download` | Download item binary content | personal_data | Files.Read |
| `microsoft.onedrive.items.delta` | Track changes via delta endpoint | personal_data | Files.Read |

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

### Sharing

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.onedrive.item.create_link` | Create a sharing link for an item | personal_data | always | Files.ReadWrite |

### Permissions

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.onedrive.item.permissions.list` | List permissions on an item | personal_data | — | Files.Read |
| `microsoft.onedrive.item.permission.get` | Get a specific permission | personal_data | — | Files.Read |
| `microsoft.onedrive.item.permission.create` | Invite users to an item | personal_data | always | Files.ReadWrite |
| `microsoft.onedrive.item.permission.delete` | Remove a permission | personal_data | always | Files.ReadWrite |

## Scope Matrix

### Required Scopes by Action

| Action | Primary Scope | Accepted Alternatives |
|---|---|---|
| `items.list` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.get` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `drive.get` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `drives.list` | Files.Read.All | Files.ReadWrite.All |
| `items.search` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.download` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `items.delta` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.create` | Files.ReadWrite | Files.ReadWrite.All |
| `item.update` | Files.ReadWrite | Files.ReadWrite.All |
| `item.upload` | Files.ReadWrite | Files.ReadWrite.All |
| `item.delete` | Files.ReadWrite | Files.ReadWrite.All |
| `item.create_link` | Files.ReadWrite | Files.ReadWrite.All |
| `item.permissions.list` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.permission.get` | Files.Read | Files.Read.All, Files.ReadWrite, Files.ReadWrite.All |
| `item.permission.create` | Files.ReadWrite | Files.ReadWrite.All |
| `item.permission.delete` | Files.ReadWrite | Files.ReadWrite.All |

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

| Pack ID | Risk | Description |
|---|---|---|
| `:microsoft_onedrive_metadata` | read | List items, drives, search, and delta — no detail or mutation |
| `:microsoft_onedrive_triage` | — | Adds item get and download detail reads |
| `:microsoft_onedrive_write` | — | Adds item create, update, and upload |
| `:microsoft_onedrive_destructive` | destructive | Adds permanent item delete |
| `:microsoft_onedrive_sharing` | — | Adds sharing links and permission management (excludes permission delete) |
| `:microsoft_onedrive_admin` | destructive | Full access including permission deletion |

### Pack Composition

```
metadata:    items.list, drive.get, drives.list, items.search, items.delta
triage:      metadata + item.get, item.download
write:       triage + item.create, item.update, item.upload
destructive: write + item.delete
sharing:     destructive + item.create_link, item.permissions.list,
             item.permission.get, item.permission.create
admin:       sharing + item.permission.delete
```

### Example

```elixir
Jido.Connect.Catalog.search_tools("onedrive",
  modules: [Jido.Connect.MicrosoftOnedrive],
  packs: Jido.Connect.MicrosoftOnedrive.catalog_packs(),
  pack: :microsoft_onedrive_metadata
)
```

## Live Smoke Tests

Env-gated read-only live smoke hooks exercise real Microsoft Graph API calls
against the authenticated user's OneDrive. These tests are **excluded by
default** and require a valid `MICROSOFT_ACCESS_TOKEN` environment variable.

```sh
MICROSOFT_ACCESS_TOKEN="eyJ..." \
  mix test test/jido_connect/microsoft_onedrive/live_smoke_test.exs --include live_smoke
```

Optional fixture ids for deeper smoke coverage:

- `MICROSOFT_ONEDRIVE_DRIVE_ID` — Fetches a specific drive when set.
- `MICROSOFT_ONEDRIVE_ITEM_ID` — Fetches a specific drive item when set.

### Safety

- Read-only tests exercise list, get, search, and delta endpoints — no items
  are created, updated, or deleted.
- Write and destructive tests are gated behind `MICROSOFT_LIVE_DESTRUCTIVE`
  to prevent accidental data mutation.
- No tokens, secrets, or credential material are logged or exposed in test
  output.
- Tests skip automatically when `MICROSOFT_ACCESS_TOKEN` is not set.

## .env.example Fixture Placeholders

The root `.env.example` file includes the following Microsoft Graph and
OneDrive fixture placeholders for local smoke testing:

```sh
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=
MICROSOFT_TENANT_ID=common
MICROSOFT_REDIRECT_URI=http://localhost:4000/integrations/microsoft/oauth/callback
MICROSOFT_ACCESS_TOKEN=
MICROSOFT_REFRESH_TOKEN=
MICROSOFT_USER_ID=me
MICROSOFT_ONEDRIVE_DRIVE_ID=
MICROSOFT_ONEDRIVE_ITEM_ID=
```

## Delta / Watch Design

See [docs/delta-watch-design.md](docs/delta-watch-design.md) for the
change-detection trigger design note covering delta token polling, Graph
webhook subscriptions, and hybrid approaches.

## License

MIT
