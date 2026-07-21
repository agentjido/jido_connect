# Jido Connect Salesforce

Salesforce CRM provider package for Jido Connect.

This package provides a Salesforce integration for Jido Connect, supporting
contacts, accounts, opportunities, leads, and tasks via the Salesforce REST API
(SOQL and SObject endpoints).

## Status

This is an **experimental** scaffold. Action fragments, normalized structs,
catalog packs, and trigger fragments will be expanded in subsequent waves.

## Auth Profiles

The provider supports two authentication profiles:

- **OAuth2 connected-app** (`:oauth2_connected_app`): Standard OAuth2
  authorization code flow with PKCE against a Salesforce connected app.
  Recommended for production integrations. Grants scoped access on behalf of
  a Salesforce user.

- **Username/password** (`:username_password`): Salesforce username-password
  OAuth flow for development and CI. Authenticates using org credentials
  directly.

## Instance URL Handling

Salesforce REST APIs are scoped to an org-specific instance URL
(e.g., `https://myorg.my.salesforce.com`). The instance URL is obtained from
the OAuth token response and stored as a credential field (`:instance_url`).
The REST transport boundary uses this URL as the base for all API requests.

## Salesforce OAuth Scopes

| Scope | Description |
|---|---|
| `api` | Access to Salesforce REST API |
| `refresh_token,offline_access` | Long-lived token refresh |
| `cdp_api` | Customer Data Platform access (optional) |

## API Version

The REST transport targets Salesforce API version `60.0` by default,
configurable via application env:

```elixir
config :jido_connect_salesforce, salesforce_api_version: "61.0"
```

## API Boundaries

All Salesforce API traffic uses
`Jido.Connect.Salesforce.Client.Transport.api_request/3`, which builds bearer
requests against the org-specific instance URL and API version.

## Catalog Packs

The provider ships two curated catalog packs for scoping tool discovery
and invocation:

| Pack | Risk | Description |
|------|------|-------------|
| `:salesforce_reader` | read | Contact queries and generic SObject reads |
| `:salesforce_editor` | write | Reader + contact, lead, task, and generic record mutations |

Triggers are subscribed to independently and are not listed in packs.

### Reader Pack Tools

| Tool ID | Resource | Description |
|---------|----------|-------------|
| `salesforce.contacts.contact.get` | contact | Fetch a contact by ID |
| `salesforce.contacts.contact.list` | contact | List contacts via SOQL |
| `salesforce.crm.query` | sobject | Execute a SOQL query |
| `salesforce.crm.record.get` | sobject | Fetch a record by type and ID |
| `salesforce.crm.object.describe` | sobject | Describe SObject metadata |
| `salesforce.crm.record.list_recent` | sobject | List recently modified records |
| `salesforce.crm.query_more` | sobject | Fetch next page of a SOQL query |

### Editor Pack Tools (reader + write)

| Tool ID | Resource | Description |
|---------|----------|-------------|
| `salesforce.contacts.contact.create` | contact | Create a new contact |
| `salesforce.contacts.contact.update` | contact | Update an existing contact |
| `salesforce.crm.lead.create` | lead | Create a new lead |
| `salesforce.crm.lead.update` | lead | Update an existing lead |
| `salesforce.crm.task.create` | task | Create a new task |
| `salesforce.crm.task.update` | task | Update an existing task |
| `salesforce.crm.record.create` | sobject | Create a record for any SObject type |
| `salesforce.crm.record.update` | sobject | Update a record for any SObject type |

### Usage

```elixir
alias Jido.Connect.Salesforce

# List available packs
packs = Salesforce.catalog_packs()
# => [%Pack{id: :salesforce_reader, ...}, %Pack{id: :salesforce_editor, ...}]

# Search tools within a pack
alias Jido.Connect.Catalog

results =
  Catalog.search_tools("contact",
    modules: [Salesforce],
    packs: Salesforce.catalog_packs(),
    pack: :salesforce_reader
  )

# Describe a specific tool
{:ok, descriptor} =
  Catalog.describe_tool("salesforce.contacts.contact.get",
    modules: [Salesforce],
    packs: Salesforce.catalog_packs(),
    pack: :salesforce_reader
  )
```

## Scope Matrix

Each action maps to the narrowest set of Salesforce scopes required:

| Operation | Required Scopes |
|-----------|----------------|
| `salesforce.contacts.contact.get` | `api` |
| `salesforce.contacts.contact.list` | `api` |
| `salesforce.contacts.contact.create` | `api` |
| `salesforce.contacts.contact.update` | `api` |
| `salesforce.crm.lead.create` | `api` |
| `salesforce.crm.lead.update` | `api` |
| `salesforce.crm.task.create` | `api` |
| `salesforce.crm.task.update` | `api` |
| `salesforce.crm.query` | `api` |
| `salesforce.crm.record.get` | `api` |
| `salesforce.crm.record.create` | `api` |
| `salesforce.crm.record.update` | `api` |
| `salesforce.crm.object.describe` | `api` |
| `salesforce.crm.record.list_recent` | `api` |
| `salesforce.crm.query_more` | `api` |

## Privacy Classification

| Operation | Classification | Risk | Confirmation |
|-----------|---------------|------|-------------|
| Contact get/list | `personal_data` | read | none |
| Contact create/update | `personal_data` | write | required_for_ai |
| Lead create/update | `personal_data` | write | required_for_ai |
| Task create/update | `workspace_content` | write | required_for_ai |
| SOQL query | `workspace_content` | read | none |
| Record get | `workspace_content` | read | none |
| Record list recent | `workspace_content` | read | none |
| Query more | `workspace_content` | read | none |
| Record create/update | `workspace_content` | write | required_for_ai |
| Describe object | `tool_metadata` | read | none |

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, generated
plugin surface, catalog packs, scope matrix, and privacy classification
through injected fake clients and does **not** call live Salesforce APIs.

### Running Against a Live Salesforce Org

When you need to validate against a real Salesforce org:

1. **Use a dedicated Salesforce Developer Edition or Sandbox** — never
   production orgs.

2. **Use the username/password flow for CI** — store org credentials in
   environment variables, never in version control.

3. **Do not hardcode tokens** — store access tokens, refresh tokens, and
   client secrets in environment variables or a secrets manager.

4. **Start with the reader pack** — validate read-only actions first using
   `Salesforce.catalog_packs()` with the `:salesforce_reader` pack. This
   requires only the `api` scope and avoids accidental data mutation.

5. **Upgrade to editor for write tests** — once read actions pass, switch
   to the `:salesforce_editor` pack to exercise contact, lead, task, and
   generic record creation and updates.

6. **Verify scope enforcement** — connect with read-only scopes and confirm
   that write actions return `{:error, %AuthError{reason: :missing_scopes}}`
   before testing with full scopes.

7. **Clean up test data** — remove contacts, leads, and tasks created during
   live testing from your Salesforce org after each session.

### Environment Variables for Live Testing

```sh
export SF_USERNAME="user@example.com"
export SF_PASSWORD="your-password"
export SF_CLIENT_ID="your-connected-app-client-id"
export SF_CLIENT_SECRET="your-connected-app-client-secret"
# Never commit these values to version control.
```

The connector reads credentials at runtime through the credential lease
mechanism; no code changes are needed to switch between mock and live clients.

## Package Quality Gates

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_salesforce
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_salesforce/test --no-deps-check
```

## Future Work: Sync Triggers

The Salesforce connector does not yet include trigger fragments. A design note
for CDC, polling, and webhook trigger patterns is available in
[`docs/sync-trigger-design.md`](docs/sync-trigger-design.md).
