# jido_connect_microsoft_sharepoint

`jido_connect_microsoft_sharepoint` connects Jido Connect to SharePoint Online
through Microsoft Graph v1.0. It supports delegated user access and application
access.

The package uses `jido_connect_microsoft` for Microsoft identity and Graph
transport. It uses `jido_connect_microsoft_onedrive` for document library drive
and drive-item operations.

## Capabilities

The connector provides these groups of tools:

- Resolve, get, and search SharePoint sites.
- List lists, get one list, and list columns.
- List, get, create, update, delete, and track list items.
- List document libraries.
- List, get, search, download, and track library items.
- Create folders, upload small files, rename items, and delete items.

SharePoint pages and webhook subscription lifecycle tools are not part of this
first version.

## Authentication

The `:user` profile uses the Microsoft authorization-code flow with PKCE. The
`:application` profile uses the Microsoft client-credentials flow and a tenant
specific token URL.

For a user connection, configure these values:

```text
MICROSOFT_CLIENT_ID
MICROSOFT_CLIENT_SECRET
MICROSOFT_REDIRECT_URI
```

For an application connection, configure these values:

```text
MICROSOFT_CLIENT_ID
MICROSOFT_CLIENT_SECRET
MICROSOFT_TENANT_ID
```

The host owns credential storage, token refresh, selected-resource grants, and
audit storage. Do not put client secrets or tokens in action input.

## Microsoft Graph permissions

Use the least permission that supports the selected tools.

| Tool group | Common permissions |
| --- | --- |
| Site and list read | `Sites.Read.All` |
| Site and list write | `Sites.ReadWrite.All` |
| Document library read | `Files.Read.All` or `Sites.Read.All` |
| Document library write | `Files.ReadWrite.All` or `Sites.ReadWrite.All` |
| Selected resources | `Sites.Selected`, `Lists.SelectedOperations.Selected`, `ListItems.SelectedOperations.Selected`, or `Files.SelectedOperations.Selected` |

Selected scopes do not grant access by themselves. An administrator must also
grant the application a role on each selected site, list, list item, or file.

List-item delta uses `Sites.Read.All` or `Sites.ReadWrite.All`. Microsoft Graph
does not list a personal Microsoft account as a supported account for this
endpoint.

## Safe writes

All write tools have a preview and require confirmation for AI use. Delete tools
always require confirmation.

List-item update and delete tools require an ETag. Document rename and delete
tools also require an ETag. Microsoft Graph returns `412 Precondition Failed`
when the item changed after the caller read it.

Write previews show resource identifiers, field names, and content size. They do
not show list field values or file content.

The upload tool uses the Graph simple-upload endpoint. This connector limits one
upload input to 10 MB. Add an upload-session action for larger files.

## Delta synchronization

`microsoft.sharepoint.list.items.delta` reads new, changed, and deleted list
items. Start without a token for a full enumeration. Use `token: "latest"` to
start from the current state.

Pass each `next_link` back in the `cursor` input before you save the final
`delta_link`. The connector rejects a cursor from another Graph origin or
resource path. The host must keep the checkpoint. A `410 Gone` response means
that the host must start a new enumeration. A delta feed contains the latest
state, not an event for each change. An item can occur more than once, so the
last occurrence wins.

`microsoft.sharepoint.library.items.delta` provides the same type of checkpoint
flow for files and folders in a document library.

## Catalog packs

The connector exports these packs:

- `microsoft_sharepoint_metadata`: Site, list, column, and library metadata.
- `microsoft_sharepoint_read`: All read tools, including file download.
- `microsoft_sharepoint_sync`: List and library delta tools with discovery.
- `microsoft_sharepoint_write`: Read and write tools without delete tools.
- `microsoft_sharepoint_destructive`: All tools, including delete tools.

Use `Jido.Connect.MicrosoftSharepoint.catalog_packs/0` to get all packs.

## Live smoke tests

The live smoke tests are read-only. Set these values:

```text
MICROSOFT_ACCESS_TOKEN
MICROSOFT_SHAREPOINT_SITE_ID
MICROSOFT_SHAREPOINT_LIST_ID
MICROSOFT_SHAREPOINT_DRIVE_ID
```

The list and drive identifiers are optional. Tests that need an absent identifier
do not make a request.

Run the tests from the package directory:

```sh
mix test test/jido_connect/microsoft_sharepoint/live_smoke_test.exs --include live_smoke
```

The tests do not print tokens, field values, file content, or delta links.

## Privacy boundary

List field values and file content are workspace content. User names and email
addresses are personal data. Temporary download URLs and raw file content must
not enter telemetry or default metadata payloads. Use `Jido.Connect.Sanitizer`
before you emit telemetry or public diagnostic data.

## Microsoft documentation

- [SharePoint resources in Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/sharepoint)
- [List item delta](https://learn.microsoft.com/en-us/graph/api/listitem-delta?view=graph-rest-1.0)
- [List site drives](https://learn.microsoft.com/en-us/graph/api/drive-list?view=graph-rest-1.0)
- [Selected permissions overview](https://learn.microsoft.com/en-us/graph/permissions-selected-overview)
