# Jido Connect Google Slides

Google Slides provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Slides-specific DSL,
handlers, schemas, normalized structs, and tests package-local.

## Actions

- `google.slides.presentation.get` — Fetch a Google Slides presentation by
  presentation id.
- `google.slides.presentation.create` — Create a new Google Slides presentation
  with a title.
- `google.slides.presentation.batch_update` — Apply one or more updates to a
  Google Slides presentation in a single atomic request.
- `google.slides.presentation.page.get_thumbnail` — Fetch the thumbnail image
  metadata for a specific page in a Google Slides presentation.

## Auth Profiles

Slides declares a user OAuth profile:

- `:user` for app-user OAuth authorization-code grants.

Every Slides action advertises this profile through the Jido Connect action
catalog.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Slides product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/presentations.readonly`
- `https://www.googleapis.com/auth/presentations`

Read-only operations should use `presentations.readonly` when possible.
Presentation creation and mutation should require `presentations`.

## Data Classification

Every Slides action declares a data classification:

| Action | Classification | Risk | Confirmation |
|---|---|---|---|
| `google.slides.presentation.get` | `workspace_content` | `read` | `none` |
| `google.slides.presentation.create` | `workspace_metadata` | `write` | `required_for_ai` |
| `google.slides.presentation.batch_update` | `workspace_content` | `write` | `required_for_ai` |
| `google.slides.presentation.page.get_thumbnail` | `workspace_content` | `read` | `none` |

## Scope Matrix

The Slides scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| `google.slides.presentation.get` | `presentations.readonly` | Read-only access |
| `google.slides.presentation.page.get_thumbnail` | `presentations.readonly` | Read-only access |
| `google.slides.presentation.create` | `presentations` | Write required |
| `google.slides.presentation.batch_update` | `presentations` | Write required |

Write operations always require `presentations`. The readonly scope never
satisfies write operations.

## Catalog Search And Describe

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Slides

Catalog.search_tools("slides",
  modules: [Slides],
  packs: Slides.catalog_packs(),
  pack: :google_slides_readonly
)

{:ok, descriptor} =
  Catalog.describe_tool("google.slides.presentation.get",
    modules: [Slides],
    packs: Slides.catalog_packs(),
    pack: :google_slides_readonly
  )

descriptor.tool.id
#=> "google.slides.presentation.get"
```

## Tool Availability

Generated plugin availability covers every Slides action. Hosts can pass a
durable connection plus optional allow lists to see `:available`,
`:missing_scopes`, `:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.Google.Slides.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.slides.presentation.get"]
})
```

## Calling A Tool

Hosts own connection lookup, credential leasing, persistence, and policy. Pass
the runtime `context` and short-lived `credential_lease` into catalog calls:

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Slides

{:ok, result} =
  Catalog.call_tool(
    "google.slides.presentation.batch_update",
    %{
      presentation_id: "1abc...",
      requests: [%{"createSlide" => %{"insertionIndex" => 1}}]
    },
    modules: [Slides],
    packs: Slides.catalog_packs(),
    pack: :google_slides_editor,
    context: context,
    credential_lease: credential_lease
  )

result.batch_update_result.presentation_id
```

## Built-In Packs

`Slides.catalog_packs/0` returns two storage-free catalog packs:

- `:google_slides_readonly` includes presentation metadata and content reads
  only.
- `:google_slides_editor` adds presentation creation and batch updates. Includes
  all Slides tools.

Pack delegates are available directly from the provider module:

```elixir
alias Jido.Connect.Google.Slides

Slides.catalog_packs()    # [readonly_pack, editor_pack]
Slides.readonly_pack()    # :google_slides_readonly
Slides.editor_pack()      # :google_slides_editor
```

## Generated Modules

The provider generates these modules at compile time:

- **Action modules**: `Jido.Connect.Google.Slides.Actions.GetPresentation`,
  `Jido.Connect.Google.Slides.Actions.CreatePresentation`,
  `Jido.Connect.Google.Slides.Actions.BatchUpdate`,
  `Jido.Connect.Google.Slides.Actions.GetPageThumbnail`
- **Plugin module**: `Jido.Connect.Google.Slides.Plugin`
- **Manifest**: available via `Slides.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.

## Drive Trigger and Export Guidance

Google Slides presentations live in Google Drive. When integrating Slides with
Drive-powered workflows:

- **Presentation IDs are Drive file IDs**. Use
  `google.drive.file.get` with a Slides presentation ID to retrieve Drive
  metadata such as permissions, last modified time, or parent folder.
- **Export formats**. Use `google.drive.file.export` to convert a Slides
  presentation to PDF, PowerPoint (`application/vnd.openxmlformats-officedocument.presentationml.presentation`),
  plain text, or other supported MIME types. The Slides API itself does not
  expose an export endpoint.
- **Drive change triggers**. Use `google.drive.file.changed` or
  `google.drive.file.changed.push` to detect when a Slides presentation is
  modified. The trigger payload includes the Drive file ID, which maps directly
  to the Slides presentation ID for follow-up reads via
  `google.slides.presentation.get`.
- **Drive scopes**. Export and Drive metadata require Drive scopes in addition
  to Slides scopes. Grant `drive.readonly` for export and metadata reads, or
  `drive.file` for app-managed files.

Example: export a Slides presentation to PDF after a Drive change trigger:

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

# 3. Read the latest presentation content via Slides
Catalog.call_tool("google.slides.presentation.get",
  %{presentation_id: file_id},
  modules: [Slides],
  packs: Slides.catalog_packs(),
  pack: :google_slides_readonly,
  context: context,
  credential_lease: lease
)
```
