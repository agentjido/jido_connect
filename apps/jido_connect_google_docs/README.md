# Jido Connect Google Docs

Google Docs provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Docs-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Actions

- `google.docs.document.get` — Fetch a Google Docs document by document id.
- `google.docs.document.create` — Create a new Google Docs document with an optional title.
- `google.docs.document.batch_update` — Run a validated batchUpdate request for text, style, table, and image operations.

## Auth Profiles

Docs declares a user OAuth profile:

- `:user` for app-user OAuth authorization-code grants.

Every Docs action advertises this profile through the Jido Connect action
catalog.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Docs product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/documents.readonly`
- `https://www.googleapis.com/auth/documents`

Read-only operations should use `documents.readonly` when possible. Document
creation and mutation should require `documents`.

## Data Classification

Every Docs action declares a data classification:

| Action | Classification | Risk | Confirmation |
|---|---|---|---|
| `google.docs.document.get` | `workspace_content` | `read` | `none` |
| `google.docs.document.create` | `workspace_metadata` | `write` | `required_for_ai` |
| `google.docs.document.batch_update` | `workspace_content` | `destructive` | `always` |

## Scope Matrix

The Docs scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| `google.docs.document.get` | `documents.readonly` | Read-only access |
| `google.docs.document.create` | `documents` | Write required |
| `google.docs.document.batch_update` | `documents` | Write required |

Write operations always require `documents`. The readonly scope never satisfies
write operations.

## API Boundaries

- Google Docs v1 traffic should use
  `Jido.Connect.Google.Docs.Client.Transport.docs_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Catalog Packs

- `:google_docs_readonly` includes document metadata and content reads only.
- `:google_docs_editor` adds document creation and batch update. Includes all
  Docs tools.

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Docs

# Search for read-only tools
Catalog.search_tools("docs",
  modules: [Docs],
  packs: Docs.catalog_packs(),
  pack: :google_docs_readonly
)

# Describe a tool within a pack
{:ok, descriptor} =
  Catalog.describe_tool("google.docs.document.get",
    modules: [Docs],
    packs: Docs.catalog_packs(),
    pack: :google_docs_readonly
  )

# Call a tool within pack restrictions
{:ok, result} =
  Catalog.call_tool(
    "google.docs.document.get",
    %{document_id: "1abc..."},
    modules: [Docs],
    packs: Docs.catalog_packs(),
    pack: :google_docs_readonly,
    context: context,
    credential_lease: lease
  )
```

Pack delegates are available directly from the provider module:

```elixir
Docs.catalog_packs()    # [readonly_pack, editor_pack]
Docs.readonly_pack()    # :google_docs_readonly
Docs.editor_pack()      # :google_docs_editor
```

## Tool Availability

Generated plugin availability covers every Docs action. Hosts can pass a
durable connection plus optional allow lists to see `:available`,
`:missing_scopes`, `:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.Google.Docs.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.docs.document.get"]
})
```

## Generated Modules

The provider generates these modules at compile time:

- **Action modules**: `Jido.Connect.Google.Docs.Actions.GetDocument`,
  `Jido.Connect.Google.Docs.Actions.CreateDocument`,
  `Jido.Connect.Google.Docs.Actions.BatchUpdateDocument`
- **Plugin module**: `Jido.Connect.Google.Docs.Plugin`
- **Manifest**: available via `Docs.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.

## Drive Trigger and Export Guidance

Google Docs documents live in Google Drive. When integrating Docs with
Drive-powered workflows:

- **Document IDs are Drive file IDs**. Use
  `google.drive.file.get` with a Docs document ID to retrieve Drive metadata
  such as permissions, last modified time, or parent folder.
- **Export formats**. Use `google.drive.file.export` to convert a Docs document
  to PDF, HTML, plain text, or other supported MIME types. The Docs API itself
  does not expose an export endpoint.
- **Drive change triggers**. Use `google.drive.file.changed` or
  `google.drive.file.changed.push` to detect when a Docs document is modified.
  The trigger payload includes the Drive file ID, which maps directly to the
  Docs document ID for follow-up reads via `google.docs.document.get`.
- **Drive scopes**. Export and Drive metadata require Drive scopes in addition
  to Docs scopes. Grant `drive.readonly` for export and metadata reads, or
  `drive.file` for app-managed files.

Example: export a Docs document to PDF after a Drive change trigger:

```elixir
# 1. Drive push trigger fires with file_id
# 2. Export via Drive
Catalog.call_tool("google.drive.file.export",
  %{file_id: file_id, mime_type: "application/pdf"},
  modules: [Jido.Connect.Google.Drive],
  packs: Jido.Connect.Google.Drive.catalog_packs(),
  pack: :google_drive_readonly,
  context: context,
  credential_lease: lease
)

# 3. Read the latest content via Docs
Catalog.call_tool("google.docs.document.get",
  %{document_id: file_id},
  modules: [Docs],
  packs: Docs.catalog_packs(),
  pack: :google_docs_readonly,
  context: context,
  credential_lease: lease
)
```
