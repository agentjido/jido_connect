# Jido Connect Google Forms

Google Forms provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Forms-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Actions

- `google.forms.form.get` — Fetch a Google Forms form by form id.

## Auth Profiles

Forms declares a user OAuth profile:

- `:user` for app-user OAuth authorization-code grants.

Every Forms action advertises this profile through the Jido Connect action
catalog.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Forms product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/forms.body.readonly`
- `https://www.googleapis.com/auth/forms.body`
- `https://www.googleapis.com/auth/forms.responses.readonly`
- `https://www.googleapis.com/auth/forms.responses`

Read-only operations should use `forms.body.readonly` or
`forms.responses.readonly` when possible. Form creation, mutation, and
response writes should require `forms.body` or `forms.responses`.

## Data Classification

Every Forms action declares a data classification:

| Action | Classification | Risk | Confirmation |
|---|---|---|---|
| `google.forms.form.get` | `workspace_content` | `read` | `none` |

## Scope Matrix

The Forms scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| `google.forms.form.get` | `forms.body.readonly` | Read-only access |

Write operations (to be added) will require `forms.body` or `forms.responses`.

## API Boundaries

- Google Forms v1 traffic should use
  `Jido.Connect.Google.Forms.Client.Transport.forms_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Catalog Packs

- `:google_forms_readonly` includes form metadata and content reads only.
- `:google_forms_editor` adds form creation, mutation, and response
  management. Includes all Forms tools.

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Forms

# Search for read-only tools
Catalog.search_tools("forms",
  modules: [Forms],
  packs: Forms.catalog_packs(),
  pack: :google_forms_readonly
)

# Describe a tool within a pack
{:ok, descriptor} =
  Catalog.describe_tool("google.forms.form.get",
    modules: [Forms],
    packs: Forms.catalog_packs(),
    pack: :google_forms_readonly
  )

# Call a tool within pack restrictions
{:ok, result} =
  Catalog.call_tool(
    "google.forms.form.get",
    %{form_id: "1abc..."},
    modules: [Forms],
    packs: Forms.catalog_packs(),
    pack: :google_forms_readonly,
    context: context,
    credential_lease: lease
  )
```

Pack delegates are available directly from the provider module:

```elixir
Forms.catalog_packs()    # [readonly_pack, editor_pack]
Forms.readonly_pack()    # :google_forms_readonly
Forms.editor_pack()      # :google_forms_editor
```

## Tool Availability

Generated plugin availability covers every Forms action. Hosts can pass a
durable connection plus optional allow lists to see `:available`,
`:missing_scopes`, `:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.Google.Forms.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["google.forms.form.get"]
})
```

## Generated Modules

The provider generates these modules at compile time:

- **Action modules**: `Jido.Connect.Google.Forms.Actions.GetForm`
- **Plugin module**: `Jido.Connect.Google.Forms.Plugin`
- **Manifest**: available via `Forms.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.
