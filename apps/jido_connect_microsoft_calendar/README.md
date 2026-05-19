# jido_connect_microsoft_calendar

Microsoft Calendar connector package for Jido Connect.

Builds on the shared `jido_connect_microsoft` foundation package for OAuth
profiles, Graph transport, pagination, scopes, and error normalization. This
package owns the Microsoft Calendar integration DSL, action catalog, scope
resolver, privacy boundaries, catalog packs, and env-gated live smoke hooks.

## Installation

This package is part of the `jido_connect` umbrella and depends on
`jido_connect` and `jido_connect_microsoft`.

```elixir
def deps do
  [
    {:jido_connect_microsoft_calendar, in_umbrella: true}
  ]
end
```

## Usage

```elixir
# Get the integration spec
spec = Jido.Connect.MicrosoftCalendar.integration()

# List declared actions
spec.actions

# List catalog packs
Jido.Connect.MicrosoftCalendar.catalog_packs()
```

## Architecture

- **Integration DSL** – Declares the `microsoft_calendar` provider with
  calendar and event actions, auth profiles reused from the Microsoft
  foundation, and catalog metadata.
- **Scope Resolver** – Maps action ids to required Microsoft Graph calendar
  scopes (`Calendars.Read`, `Calendars.ReadWrite`, `Calendars.Read.Shared`,
  `Calendars.ReadWrite.Shared`) with least-privilege resolution against
  existing grants.
- **Catalog Packs** – Curated tool surfaces (metadata, triage, write,
  destructive) for host policy enforcement.
- **Action Handlers** – Initial scaffold returns `{:error, :not_implemented}`.
  Full Graph API integration will be added in follow-up tasks.
- **Privacy Boundary** – Event body content and sensitive attendee data are
  intentionally excluded from normalized structs. See "Privacy Boundary" below.

## Actions

### Read

| Action ID | Description | Classification | Scopes |
|---|---|---|---|
| `microsoft.calendar.calendars.list` | List calendars for authenticated user | personal_data | Calendars.Read |
| `microsoft.calendar.calendar.get` | Get a single calendar by id | personal_data | Calendars.Read |
| `microsoft.calendar.events.list` | List events for a calendar | personal_data | Calendars.Read |
| `microsoft.calendar.event.get` | Get a single event by id | personal_data | Calendars.Read |

### Write

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.calendar.event.create` | Create a new event | personal_data | required_for_ai | Calendars.ReadWrite |
| `microsoft.calendar.event.update` | Update an existing event | personal_data | required_for_ai | Calendars.ReadWrite |

### Destructive

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.calendar.event.delete` | Permanently delete an event | personal_data | always | Calendars.ReadWrite |

## Privacy Boundary

Calendar data can contain sensitive scheduling and personal information. The
connector classifies event subjects, body previews, attendee addresses, and
location metadata as calendar content or personal data depending on the action.
Normalized event structs intentionally avoid full body HTML/text content:

- **Body summaries** contain only `content_type` and `body_size` — never the
  raw body string.
- **Attendee metadata** will be limited to name and address fields only.

The `Jido.Connect.MicrosoftCalendar.Privacy` module documents which fields
carry calendar content versus personal data and provides a `raw_body_key?/1`
guard for filtering sensitive keys.

## Catalog Packs

- **`:microsoft_calendar_metadata`** — Read-only calendar and event list
  metadata. No detail, mutation, or delete tools.
- **`:microsoft_calendar_triage`** — Adds calendar get and event get detail
  tools. Excludes create, update, and delete tools.
- **`:microsoft_calendar_write`** — Adds event create and update. Excludes
  detail and delete tools.
- **`:microsoft_calendar_destructive`** — Adds permanent event delete
  operations.

```elixir
Jido.Connect.Catalog.search_tools("calendar",
  modules: [Jido.Connect.MicrosoftCalendar],
  packs: Jido.Connect.MicrosoftCalendar.catalog_packs(),
  pack: :microsoft_calendar_triage
)
```

## Tool Availability

Generated plugin availability covers every Calendar action. Hosts can pass a
durable connection plus optional allow lists to see `:available`,
`:missing_scopes`, `:connection_required`, or `:disabled_by_policy` per tool:

```elixir
Jido.Connect.MicrosoftCalendar.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["microsoft.calendar.events.list"]
})
```

## Scopes

The connector prefers narrow Microsoft Graph scopes:

- `Calendars.Read` for calendar and event listing and retrieval.
  `Calendars.ReadWrite` can satisfy read tools when a host already has broader
  grants.
- `Calendars.Read.Shared` can satisfy reads when granted.
- `Calendars.ReadWrite` for event create, update, and delete operations.
- `Calendars.ReadWrite.Shared` can satisfy write operations when granted.

## Live Smoke Tests

Env-gated read-only live smoke hooks exercise real Microsoft Graph API calls
against the authenticated user's calendar. These tests are **excluded by
default** and require a valid `MICROSOFT_ACCESS_TOKEN` environment variable.

```sh
MICROSOFT_ACCESS_TOKEN="eyJ..." \
  mix test test/jido_connect/microsoft_calendar/live_smoke_test.exs --include live_smoke
```

### Safety

- All live smoke tests are read-only — no events are created, updated, or
  deleted.
- No tokens, secrets, or credential material are logged or exposed in test
  output.
- Tests skip automatically when `MICROSOFT_ACCESS_TOKEN` is not set.

## License

MIT
