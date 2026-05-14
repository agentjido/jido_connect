# Jido Connect Google Sheets

`jido_connect_google_sheets` is the Google Sheets provider package for
`jido_connect`.

It depends on `jido_connect_google` for shared Google auth, transport, scope,
pagination, and account helpers.

## Installation

```elixir
def deps do
  [
    {:jido_connect, "~> 0.1.0"},
    {:jido_connect_google, "~> 0.1.0"},
    {:jido_connect_google_sheets, "~> 0.1.0"}
  ]
end
```

For Git dependencies during local integration testing:

```elixir
def deps do
  [
    {:jido_connect_google_sheets,
     github: "agentjido/jido_connect",
     sparse: "apps/jido_connect_google_sheets"}
  ]
end
```

## OAuth Scopes

The provider declares the shared Google identity scopes plus Sheets product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/spreadsheets.readonly`
- `https://www.googleapis.com/auth/spreadsheets`

Basic read actions accept either the read-only Sheets scope or the full Sheets
scope. Google Sheets data-filter and developer metadata endpoints require
`https://www.googleapis.com/auth/spreadsheets`, even when the action is
read-only. Write actions also require `https://www.googleapis.com/auth/spreadsheets`.

## Tool Surface

Implemented actions:

- `google.sheets.spreadsheet.get`
- `google.sheets.spreadsheet.create`
- `google.sheets.spreadsheet.get_by_data_filter`
- `google.sheets.values.get`
- `google.sheets.values.batch_get`
- `google.sheets.values.batch_get_by_data_filter`
- `google.sheets.values.update`
- `google.sheets.values.append`
- `google.sheets.values.clear`
- `google.sheets.values.batch_update`
- `google.sheets.values.batch_update_by_data_filter`
- `google.sheets.values.batch_clear`
- `google.sheets.values.batch_clear_by_data_filter`
- `google.sheets.developer_metadata.get`
- `google.sheets.developer_metadata.search`
- `google.sheets.sheet.add`
- `google.sheets.sheet.delete`
- `google.sheets.sheet.rename`
- `google.sheets.batch_update`

## Catalog Search And Describe

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Sheets

Catalog.search_tools("sheet values",
  modules: [Sheets],
  packs: Sheets.catalog_packs(),
  pack: :google_sheets_readonly
)

{:ok, descriptor} =
  Catalog.describe_tool("google.sheets.values.get",
    modules: [Sheets],
    packs: Sheets.catalog_packs(),
    pack: :google_sheets_readonly
  )

descriptor.tool.id
#=> "google.sheets.values.get"
```

## Calling A Tool

Hosts own connection lookup, credential leasing, persistence, and policy. Pass
the runtime `context` and short-lived `credential_lease` into catalog calls:

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Sheets

{:ok, result} =
  Catalog.call_tool(
    "google.sheets.values.update",
    %{
      spreadsheet_id: "1abc...",
      range: "Sheet1!A1:B2",
      values: [["Name", "Count"], ["A", 1]],
      value_input_option: "USER_ENTERED"
    },
    modules: [Sheets],
    packs: Sheets.catalog_packs(),
    pack: :google_sheets_writer,
    context: context,
    credential_lease: credential_lease
  )

result.update.updated_cells
```

## Built-In Packs

`Sheets.catalog_packs/0` returns two storage-free catalog packs:

- `:google_sheets_readonly` exposes spreadsheet metadata reads and single or
  batch value reads that work with `spreadsheets.readonly`.
- `:google_sheets_writer` exposes read tools, spreadsheet creation, value
  writes, value batch writes/clears, provider-specific data-filter tools,
  developer metadata tools, and sheet add/delete/rename. It intentionally
  excludes raw `google.sheets.batch_update`.

Data-filter inputs use Google Sheets DataFilter shape inside this provider
package, for example `%{a1Range: "Sheet1!A1:B2"}` or
`%{developerMetadataLookup: %{metadataKey: "sync_id"}}`. Snake-case aliases such
as `%{a1_range: "Sheet1!A1:B2"}` are normalized to Google's JSON field names.

Use the raw batch update action outside the writer pack when a host explicitly
wants to expose the full Google Sheets batchUpdate escape hatch.
