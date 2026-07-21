# Jido Connect Google Forms

Google Forms provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Forms-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Installation

```elixir
def deps do
  [
    {:jido_connect, "~> 0.8"},
    {:jido_connect_google, "~> 0.8"},
    {:jido_connect_google_forms, "~> 0.8"}
  ]
end
```

For Git dependencies during local integration testing:

```elixir
def deps do
  [
    {:jido_connect_google_forms,
     github: "agentjido/jido_connect",
     sparse: "apps/jido_connect_google_forms"}
  ]
end
```

## Actions

| Action | Description |
|---|---|
| `google.forms.form.get` | Fetch a Google Forms form by form id |
| `google.forms.form.create` | Create a new Google Form |
| `google.forms.form.batch_update` | Batch-update a form with multiple requests |
| `google.forms.responses.list` | List form responses |
| `google.forms.responses.get` | Get a single form response |
| `google.forms.watch.create` | Create a watch for form events |
| `google.forms.watch.renew` | Renew an existing watch |
| `google.forms.watch.delete` | Delete a watch |

## Triggers

| Trigger | Description |
|---|---|
| `google.forms.response.submitted` | Fires when a form response is submitted |

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
`forms.responses.readonly` when possible. Form creation and mutation require
`forms.body`. Response and watch operations require
`forms.responses.readonly`.

## Data Classification

Every Forms action declares a data classification:

| Action | Classification | Risk | Confirmation |
|---|---|---|---|
| `google.forms.form.get` | `workspace_content` | `read` | `none` |
| `google.forms.form.create` | `workspace_metadata` | `write` | `required_for_ai` |
| `google.forms.form.batch_update` | `workspace_content` | `destructive` | `always` |
| `google.forms.responses.list` | `personal_data` | `read` | `none` |
| `google.forms.responses.get` | `personal_data` | `read` | `none` |
| `google.forms.watch.create` | `workspace_metadata` | `write` | `required_for_ai` |
| `google.forms.watch.renew` | `workspace_metadata` | `write` | `required_for_ai` |
| `google.forms.watch.delete` | `workspace_metadata` | `write` | `required_for_ai` |

## Scope Matrix

The Forms scope resolver maps operations to least-privilege scopes:

| Operation | Required Scope | Notes |
|---|---|---|
| `google.forms.form.get` | `forms.body.readonly` | Read-only form body |
| `google.forms.form.create` | `forms.body` | Write scope required |
| `google.forms.form.batch_update` | `forms.body` | Write scope required |
| `google.forms.responses.list` | `forms.responses.readonly` | Response read scope |
| `google.forms.responses.get` | `forms.responses.readonly` | Response read scope |
| `google.forms.watch.create` | `forms.responses.readonly` | Watch requires response access |
| `google.forms.watch.renew` | `forms.responses.readonly` | Watch requires response access |
| `google.forms.watch.delete` | `forms.responses.readonly` | Watch requires response access |

## API Boundaries

- Google Forms v1 traffic should use
  `Jido.Connect.Google.Forms.Client.Transport.forms_request/1`.

The request builder delegates to `Jido.Connect.Google.Transport` and is
configurable through application environment for tests.

## Catalog Packs

`Forms.catalog_packs/0` returns three storage-free catalog packs in ascending
privilege order:

| Pack | ID | Risk | Included Tools |
|---|---|---|---|
| **Read-only** | `:google_forms_readonly` | `:read` | `form.get`, `responses.list`, `responses.get` |
| **Responder** | `:google_forms_responder` | `:write` | All read-only + `watch.create`, `watch.renew`, `watch.delete` |
| **Editor** | `:google_forms_editor` | `:write` | All tools including `form.create`, `form.batch_update` |

Pack delegates are available directly from the provider module:

```elixir
Forms.catalog_packs()    # [readonly_pack, responder_pack, editor_pack]
Forms.readonly_pack()    # :google_forms_readonly
Forms.responder_pack()   # :google_forms_responder
Forms.editor_pack()      # :google_forms_editor
```

### Usage — Search and Describe

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
  Catalog.describe_tool("google.forms.responses.list",
    modules: [Forms],
    packs: Forms.catalog_packs(),
    pack: :google_forms_responder
  )
```

### Usage — Call a Tool

Hosts own connection lookup, credential leasing, persistence, and policy. Pass
the runtime `context` and short-lived `credential_lease` into catalog calls:

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Google.Forms

# Read a form (readonly pack)
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

result.form.title

# List responses (responder pack)
{:ok, %{responses: responses}} =
  Catalog.call_tool(
    "google.forms.responses.list",
    %{form_id: "1abc..."},
    modules: [Forms],
    packs: Forms.catalog_packs(),
    pack: :google_forms_responder,
    context: context,
    credential_lease: lease
  )

# Create a form (editor pack)
{:ok, %{form: form}} =
  Catalog.call_tool(
    "google.forms.form.create",
    %{title: "Customer Survey"},
    modules: [Forms],
    packs: Forms.catalog_packs(),
    pack: :google_forms_editor,
    context: context,
    credential_lease: lease
  )
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

- **Action modules**: `Jido.Connect.Google.Forms.Actions.GetForm`,
  `CreateForm`, `BatchUpdateForm`, `ListResponses`, `GetResponse`,
  `CreateWatch`, `RenewWatch`, `DeleteWatch`
- **Sensor module**: `Jido.Connect.Google.Forms.Sensors.ResponseSubmitted`
- **Plugin module**: `Jido.Connect.Google.Forms.Plugin`
- **Manifest**: available via `Forms.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.

## Live-Test Guidance

The offline test suite exercises every action, trigger, scope, pack, and
privacy boundary through injected fake clients and does **not** call live
Google APIs. When you need to validate against a real Google Forms account:

1. **Use a dedicated test Google account** — never personal or production
   accounts. Create a separate Google Workspace or Gmail account for testing.

2. **Use the OAuth playground or a staging app** — configure a Google Cloud
   project with Forms API enabled, then authorize through the OAuth
   authorization-code flow to obtain real tokens.

3. **Scope grants to the least-privilege pack** — start with
   `:google_forms_readonly` and only escalate to `:google_forms_responder` or
   `:google_forms_editor` as the test scenario demands. Verify that
   scope-restricted connections correctly report `:missing_scopes`.

4. **Exercise the full lifecycle** — create a form, submit responses via the
   Google Forms UI, list and retrieve those responses through the provider,
   then clean up by deleting the test form.

5. **Verify watch expiry and renewal** — Google Forms watches expire after 7
   days. Confirm that `watch.renew` extends the expiry and that the provider
   correctly reports `ACTIVE` / `UNDEFINED` watch state.

6. **Do not hardcode tokens** — store OAuth tokens in environment variables or
   a secrets manager. Never commit access tokens, refresh tokens, or client
   secrets to version control.

7. **Clean up** — delete all test forms and watches after each live test run
   to avoid accumulating stale resources in the test account.
