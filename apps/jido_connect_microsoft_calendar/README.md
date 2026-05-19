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
- **Action Handlers** – Full Graph API integration for calendar and event
  CRUD, free/busy schedule queries, and meeting time suggestions. RSVP
  actions (accept, decline, tentatively accept) and event cancel are
  implemented.
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
| `microsoft.calendar.schedule.get` | Get free/busy schedule for users/resources | personal_data | Calendars.Read |
| `microsoft.calendar.meeting_times.find` | Find meeting times based on availability | personal_data | Calendars.Read |

### Write / RSVP

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.calendar.event.create` | Create a new event | personal_data | required_for_ai | Calendars.ReadWrite |
| `microsoft.calendar.event.update` | Update an existing event | personal_data | required_for_ai | Calendars.ReadWrite |
| `microsoft.calendar.event.accept` | Accept an event invitation | personal_data | required_for_ai | Calendars.ReadWrite |
| `microsoft.calendar.event.decline` | Decline an event invitation | personal_data | required_for_ai | Calendars.ReadWrite |
| `microsoft.calendar.event.tentatively_accept` | Tentatively accept an event invitation | personal_data | required_for_ai | Calendars.ReadWrite |

### Destructive

| Action ID | Description | Classification | Confirmation | Scopes |
|---|---|---|---|---|
| `microsoft.calendar.event.delete` | Permanently delete an event | personal_data | always | Calendars.ReadWrite |
| `microsoft.calendar.event.cancel` | Cancel an event and notify attendees | personal_data | always | Calendars.ReadWrite |

## Scope Matrix

The connector maps each action to the narrowest required Microsoft Graph
calendar scope. Broader already-granted scopes can satisfy narrower
requirements through the `ScopeResolver` least-privilege logic.

### Required Scopes by Action

| Action | Primary Scope | Accepted Alternatives |
|---|---|---|
| `calendars.list` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `calendar.get` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `events.list` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `event.get` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `schedule.get` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `meeting_times.find` | Calendars.Read | Calendars.ReadWrite, Calendars.Read.Shared, Calendars.ReadWrite.Shared |
| `event.create` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.update` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.accept` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.decline` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.tentatively_accept` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.delete` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |
| `event.cancel` | Calendars.ReadWrite | Calendars.ReadWrite.Shared |

### Scope Hierarchy

```
Calendars.Read.Shared  ← satisfies → Calendars.Read
Calendars.ReadWrite    ← satisfies → Calendars.Read
Calendars.ReadWrite.Shared ← satisfies → Calendars.ReadWrite
                                   ← satisfies → Calendars.Read
```

### Least-Privilege Example

```elixir
# A connection with only Calendars.Read can run read actions
resolver = Jido.Connect.MicrosoftCalendar.ScopeResolver

resolver.required_scopes(
  %{id: "microsoft.calendar.calendars.list"},
  %{},
  %{scopes: ["Calendars.Read"]}
)
# => ["Calendars.Read"]

# A connection with Calendars.ReadWrite.Shared satisfies write actions
resolver.required_scopes(
  %{id: "microsoft.calendar.event.create"},
  %{},
  %{scopes: ["Calendars.ReadWrite.Shared"]}
)
# => ["Calendars.ReadWrite.Shared"]
```

## Privacy Boundary

Calendar data can contain sensitive scheduling and personal information. The
connector classifies event subjects, body previews, attendee addresses, and
location metadata as calendar content or personal data depending on the action.
Normalized event structs intentionally avoid full body HTML/text content:

- **Body summaries** contain only `content_type` and `body_size` — never the
  raw body string.
- **Attendee metadata** is limited to name and address fields only.

The `Jido.Connect.MicrosoftCalendar.Privacy` module documents which fields
carry calendar content versus personal data and provides a `raw_body_key?/1`
guard for filtering sensitive keys.

### Calendar Content Fields

`:subject`, `:body_preview`, `:body_summary`, `:organizer`, `:attendees`,
`:location`, `:start`, `:end`, `:i_cal_uid`

### Personal Data Fields

`:display_name`, `:address`, `:owner`, `:calendar_id`, `:email`,
`:subject`, `:body_preview`, `:organizer`, `:attendees`, `:location`

## Catalog Packs

- **`:microsoft_calendar_metadata`** — Read-only calendar and event list
  metadata. No detail, mutation, or delete tools.
- **`:microsoft_calendar_triage`** — Adds calendar get, event get, schedule
  get, and find meeting times tools. Excludes create, update, RSVP, and
  delete tools.
- **`:microsoft_calendar_write`** — Adds event create, update, and RSVP
  (accept, decline, tentatively accept). Excludes delete and cancel tools.
- **`:microsoft_calendar_destructive`** — Adds permanent event delete and
  cancel operations.

### Pack Composition

| Tool | metadata | triage | write | destructive |
|---|:---:|:---:|:---:|:---:|
| `calendars.list` | ✓ | ✓ | ✓ | ✓ |
| `events.list` | ✓ | ✓ | ✓ | ✓ |
| `schedule.get` | ✓ | ✓ | ✓ | ✓ |
| `calendar.get` | | ✓ | ✓ | ✓ |
| `event.get` | | ✓ | ✓ | ✓ |
| `meeting_times.find` | | ✓ | ✓ | ✓ |
| `event.create` | | | ✓ | ✓ |
| `event.update` | | | ✓ | ✓ |
| `event.accept` | | | ✓ | ✓ |
| `event.decline` | | | ✓ | ✓ |
| `event.tentatively_accept` | | | ✓ | ✓ |
| `event.delete` | | | | ✓ |
| `event.cancel` | | | | ✓ |

### Catalog Search Example

```elixir
Jido.Connect.Catalog.search_tools("calendar",
  modules: [Jido.Connect.MicrosoftCalendar],
  packs: Jido.Connect.MicrosoftCalendar.catalog_packs(),
  pack: :microsoft_calendar_triage
)
```

### Describe a Tool in a Pack

```elixir
{:ok, descriptor} =
  Jido.Connect.Catalog.describe_tool("microsoft.calendar.event.get",
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
- `Calendars.ReadWrite` for event create, update, delete, and RSVP operations.
- `Calendars.ReadWrite.Shared` can satisfy write operations when granted.

## Live Smoke Tests

Env-gated read-only live smoke hooks exercise real Microsoft Graph API calls
against the authenticated user's calendar. These tests are **excluded by
default** and require a valid `MICROSOFT_ACCESS_TOKEN` environment variable.

```sh
MICROSOFT_ACCESS_TOKEN="eyJ..." \
  mix test test/jido_connect/microsoft_calendar/live_smoke_test.exs --include live_smoke
```

### Optional Fixture IDs

- `MICROSOFT_CALENDAR_ID` — a known calendar id for detail smoke tests.
- `MICROSOFT_EVENT_ID` — a known event id for event detail smoke tests.

### Safety

- All live smoke tests are read-only — no events are created, updated, or
  deleted.
- No tokens, secrets, or credential material are logged or exposed in test
  output.
- Tests skip automatically when `MICROSOFT_ACCESS_TOKEN` is not set.

## Design Notes: Subscription / Watch / Delta

> **Status: Design notes only.** Subscription, webhook, delta query, and
> change notification features are not implemented in this wave. This section
> documents the planned design approach for future implementation.

### Microsoft Graph Subscriptions (Webhooks)

Microsoft Graph supports push notifications via `subscriptions`. Calendar
subscriptions deliver `notification` payloads when events are created, updated,
or deleted in a watched calendar or event collection.

- **Endpoint**: `POST /subscriptions` to create, `PATCH /subscriptions/{id}`
  to renew, `DELETE /subscriptions/{id}` to delete.
- **Resource types**: `/me/calendars/{id}/events` for per-calendar event
  changes, `/me/events` for all events across calendars.
- **Change types**: `created`, `updated`, `deleted`.
- **Lifecycle**: Subscriptions expire (max 3 days for most calendar resources)
  and require periodic renewal. A `lifecycleNotification` endpoint handles
  reauthorization requests.
- **Validation**: Graph sends a validation token to the notification URL on
  subscription creation. The host must echo it back synchronously.

### Delta Queries

Microsoft Graph delta queries (`/me/calendarView/delta` or
`/me/events/delta`) support incremental sync without persistent subscriptions.

- Returns a `@odata.deltaLink` on the final page. Subsequent requests with the
  delta link return only items changed since the last sync.
- Suitable for polling-based sync where webhook infrastructure is not
  available.
- Delta tokens expire after a period (typically 7 days for calendar events).

### Planned Connector Surface

When implemented, the connector would add:

| Action ID | Type | Description |
|---|---|---|
| `microsoft.calendar.events.watch` | action | Create a push subscription for event changes |
| `microsoft.calendar.subscription.renew` | action | Renew an expiring subscription |
| `microsoft.calendar.subscription.delete` | action | Delete a subscription |
| `microsoft.calendar.events.delta` | action | Fetch incremental event changes via delta link |
| `microsoft.calendar.event.changed` | trigger | Normalized event-change signal from webhook or delta |

The host would own subscription lifecycle storage, HTTPS delivery endpoint
management, and token verification. The connector would normalize Graph
notification headers and payload shapes into the standard Jido.Connect trigger
pattern, consistent with the Google Calendar webhook and poller trigger model.

## License

MIT
