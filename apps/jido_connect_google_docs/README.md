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

## Document Tabs

`google.docs.document.get` has no default for `include_tabs_content`. The
request carries Google's `includeTabsContent` only when the input sets it.

- `include_tabs_content: true` returns every tab in `document.tabs`, in
  Google's order, and no legacy `document.body`. Each tab is a map with
  `tab_id` and `title` from `tabProperties`, `body` from `documentTab.body`,
  and its nested tabs, in the same shape, in `child_tabs`.
- `include_tabs_content: false` returns only the first tab, in the legacy
  `document.body`, and `document.tabs` is empty.

The action result holds plain maps, not structs. `Client.get_document/2`
returns the same fields as a `Document` struct whose tabs and child tabs are
`Tab` structs.

Google's reference describes only `true` and `false`; the result for an
omitted value is not verified here. Other `documentTab` parts, such as
headers, footers, lists and inline objects, are not part of `Tab`.

A tab at any depth that is not a map, or whose fields do not have Google's
shape, makes the action return a `Jido.Connect.Error.ProviderError` with
reason `:invalid_response`.

## Batch Update

`google.docs.document.batch_update` sends one `documents.batchUpdate` call.
Google applies the requests in list order and all or none of them.

### Request Naming

Requests use the snake_case proto names of Google's request kinds and
fields, such as `insert_text`, `location.tab_id`, `delete_content_range` and
`range.start_index`. Google accepts these names as sent, at every nesting
level, and rejects a name it does not know with HTTP 400. The client
translates no keys: `requests` goes out unchanged, and `write_control` goes
out as Google's `writeControl` with the given map inside.

```elixir
%{
  document_id: "1abc...",
  requests: [
    %{"delete_content_range" => %{
      "range" => %{"start_index" => 20, "end_index" => 39, "tab_id" => "t.0"}
    }},
    %{"insert_text" => %{
      "location" => %{"index" => 20, "tab_id" => "t.0"},
      "text" => "replacement"
    }}
  ],
  write_control: %{"required_revision_id" => revision_id}
}
```

The action takes 1 to 100 requests. Each request holds exactly one of these
operations:

- `insert_text`, `delete_content_range`, `replace_all_text`
- `update_text_style`, `update_paragraph_style`
- `create_paragraph_bullets`, `delete_paragraph_bullets`
- `insert_table`, `update_table_cell_style`
- `insert_inline_image`, `replace_image`

Google has no request that deletes a table; delete its range with
`delete_content_range`. An empty list, more than 100 requests, a request
with no or several operations, or any other operation key, camelCase names
such as `insertText` included, returns a `Jido.Connect.Error.ValidationError`
before any request reaches Google. `Client.batch_update/2` does not validate
and passes camelCase keys through unchanged as well.

The action computes no indexes and no tab IDs. Read them with
`google.docs.document.get`; indexes count UTF-16 code units.

### Response Fields

- `document_id`: the updated document.
- `write_control`: Google's write control object as returned, such as
  `%{"requiredRevisionId" => revision_id}`, with the revision after the
  update. Google accepts it unchanged as the next request's `write_control`.
- `replies`: one reply per request, in request order. Requests without a
  reply, such as `insert_text` and `delete_content_range`, return an empty
  map.
- `document`: Google's batchUpdate response carries no document, so this
  field is absent. A response whose inline document is not a map, or has a
  tab without Google's shape, returns a `ProviderError` with reason
  `:invalid_response`.

### Revision Conflicts

When `required_revision_id` is not the document's latest revision, Google
answers HTTP 400 and applies nothing. The action returns a `ProviderError`
with reason `:http_error`, status 400 and Google's message in
`details.message`, "The required revision ID '…' does not match the latest
revision." Google uses the same status for other invalid requests; only the
message tells a revision conflict apart. The action does not retry.

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
| `google.docs.document.get` | `documents.readonly` | Read-only access; accepts an existing `documents` grant |
| `google.docs.document.create` | `documents` | Write required |
| `google.docs.document.batch_update` | `documents` | Write required |

A read requires `documents` instead of `documents.readonly` only when the
connection holds `documents` and not `documents.readonly`. Write operations
always require `documents`. The readonly scope never satisfies write
operations.

## API Boundaries

- Google Docs v1 traffic should use
  `Jido.Connect.Google.Docs.Client.Transport.docs_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Catalog Packs

- `:google_docs_readonly` includes document metadata and content reads only.
- `:google_docs_editor` adds document creation and destructive batch update.
  Its risk label is `:destructive`.

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
