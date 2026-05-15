# Jido Connect Cal.com

Cal.com provider package for Jido Connect.

This package provides a Cal.com integration for Jido Connect, supporting
event type discovery, booking management, webhook lifecycle management, and
booking webhook triggers for the Cal.com v2 API.

## Actions

### Event type actions

- `calcom.event_types.list`

### Booking actions

- `calcom.bookings.list`
- `calcom.bookings.get`
- `calcom.bookings.cancel`
- `calcom.bookings.reschedule`

### Webhook actions

- `calcom.webhooks.create`
- `calcom.webhooks.list`
- `calcom.webhooks.delete`

## Triggers

- `calcom.booking.created`
- `calcom.booking.updated`
- `calcom.booking.canceled`
- `calcom.booking.rescheduled`

All four triggers use Cal.com webhook delivery with HMAC-SHA256 signature
verification against the `x-cal-signature-256` header. Each trigger is
deduplicated by `booking_uid + trigger_event` to prevent replay.

## Auth Profiles

The provider supports two authentication profiles:

- **API key** (`:api_key`): Personal access token (`cal_`-prefixed) captured in
  the `:api_key` credential field and passed as a Bearer token. Recommended for
  development and CI.
- **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
  PKCE. Requires Cal.com admin approval of the OAuth client.

## OAuth Scopes

The provider declares Cal.com scopes for event types, bookings, and webhooks:

- `EVENT_TYPE_READ`
- `BOOKING_READ`
- `BOOKING_WRITE`
- `WEBHOOK_READ`
- `WEBHOOK_WRITE`

Read-only operations should use `EVENT_TYPE_READ`, `BOOKING_READ`, or
`WEBHOOK_READ` when possible. Booking mutation and webhook management require
`BOOKING_WRITE` or `WEBHOOK_WRITE`.

## Scope Matrix

The Cal.com scope resolver maps operations to least-privilege scopes:

| Operation | Default Scope | Notes |
|---|---|---|
| `calcom.event_types.list` | `EVENT_TYPE_READ` | Read-only |
| `calcom.bookings.list` | `BOOKING_READ` | Read-only |
| `calcom.bookings.get` | `BOOKING_READ` | Read-only |
| `calcom.bookings.cancel` | `BOOKING_WRITE` | Write required |
| `calcom.bookings.reschedule` | `BOOKING_WRITE` | Write required |
| `calcom.webhooks.create` | `WEBHOOK_WRITE` | Write required |
| `calcom.webhooks.list` | `WEBHOOK_READ` | Read-only |
| `calcom.webhooks.delete` | `WEBHOOK_WRITE` | Write required |
| `calcom.booking.created` | `BOOKING_READ` | Trigger subscription |
| `calcom.booking.updated` | `BOOKING_READ` | Trigger subscription |
| `calcom.booking.canceled` | `BOOKING_READ` | Trigger subscription |
| `calcom.booking.rescheduled` | `BOOKING_READ` | Trigger subscription |

Write operations always require the corresponding write scope. Trigger
subscriptions require only `BOOKING_READ` because they observe booking state.

## Data Classification

Every Cal.com action and trigger declares a data classification following the
Jido Connect taxonomy:

| Tool | Classification | Rationale |
|---|---|---|
| `calcom.event_types.list` | `workspace_metadata` | Event type configuration |
| `calcom.bookings.list` | `workspace_metadata` | Booking metadata (list) |
| `calcom.bookings.get` | `workspace_metadata` | Booking metadata (single) |
| `calcom.bookings.cancel` | `workspace_metadata` | Booking mutation |
| `calcom.bookings.reschedule` | `workspace_metadata` | Booking mutation |
| `calcom.webhooks.create` | `workspace_metadata` | Webhook endpoint config |
| `calcom.webhooks.list` | `workspace_metadata` | Webhook endpoint listing |
| `calcom.webhooks.delete` | `workspace_metadata` | Webhook endpoint removal |
| `calcom.booking.created` | `personal_data` | Contains attendee PII |
| `calcom.booking.updated` | `personal_data` | Contains attendee PII |
| `calcom.booking.canceled` | `personal_data` | Contains attendee PII |
| `calcom.booking.rescheduled` | `personal_data` | Contains attendee PII |

Booking webhook triggers carry `personal_data` because their payloads include
attendee names, emails, and scheduling details. Hosts should apply
`Jido.Connect.Sanitizer` before emitting telemetry or public payloads from
trigger handlers.

## API Boundaries

All Cal.com API traffic uses
`Jido.Connect.Calcom.Client.Transport.api_request/2`, which builds bearer
requests against the configurable Cal.com v2 API base URL.

Cal.com requires a `cal-api-version` header that varies per endpoint. The
transport layer applies the correct version automatically based on the action
being invoked.

## API Versioning

Cal.com v2 endpoints require a `cal-api-version` header, but the required
version differs per endpoint group. The connector stores and sends the correct
version per action:

| Endpoint Group | Required Version |
|---|---|
| Event types | `2024-06-14` |
| Bookings (list) | `2026-05-01` |
| Bookings (get, cancel, reschedule) | `2026-02-25` |
| Webhooks | `2024-06-14` |

## Normalized Structs

- `Jido.Connect.Calcom.EventType`
- `Jido.Connect.Calcom.Booking`
- `Jido.Connect.Calcom.Webhook`

## Catalog Packs

`Jido.Connect.Calcom.catalog_packs/0` returns storage-free catalog packs that
hosts can pass to the catalog boundary:

- `:calcom_reader` exposes read-only tools: event type listing and booking
  queries.
- `:calcom_booking` includes the reader tools plus booking cancel and
  reschedule actions.
- `:calcom_webhook` includes the reader tools plus webhook endpoint lifecycle
  management.
- `:calcom_full` includes all Cal.com action tools.

```elixir
alias Jido.Connect.Catalog
alias Jido.Connect.Calcom

# Search for read-only tools
Catalog.search_tools("booking",
  modules: [Calcom],
  packs: Calcom.catalog_packs(),
  pack: :calcom_reader
)

# Search for all tools
Catalog.search_tools("webhook",
  modules: [Calcom],
  packs: Calcom.catalog_packs(),
  pack: :calcom_full
)
```

Pack delegates are available directly from the provider module:

```elixir
Calcom.catalog_packs()    # [reader, booking, webhook, full]
Calcom.reader_pack()      # :calcom_reader
Calcom.booking_pack()     # :calcom_booking
Calcom.webhook_pack()     # :calcom_webhook
Calcom.full_pack()        # :calcom_full
```

## Tool Availability

Generated plugin availability covers every Cal.com action and trigger.
Hosts can pass a durable connection plus optional allow lists to see
`:available`, `:missing_scopes`, `:connection_required`, or
`:disabled_by_policy` per tool:

```elixir
Jido.Connect.Calcom.Plugin.tool_availability(%{
  connection: connection,
  allowed_actions: ["calcom.bookings.list"],
  allowed_triggers: ["calcom.booking.created"]
})
```

## Generated Modules

- **Action modules**: `Jido.Connect.Calcom.Actions.ListEventTypes`,
  `ListBookings`, `GetBooking`, `CancelBooking`, `RescheduleBooking`,
  `CreateWebhook`, `ListWebhooks`, `DeleteWebhook`
- **Sensor modules**: `Jido.Connect.Calcom.Sensors.BookingCreated`,
  `BookingUpdated`, `BookingCanceled`, `BookingRescheduled`
- **Plugin module**: `Jido.Connect.Calcom.Plugin`
- **Manifest**: available via `Calcom.jido_connect_manifest/0`

Each action module exposes `run/2`, `operation_id/0`, `name/0`, and
`to_tool/0` following the Jido Connect action contract.

## Webhook Verification

`Jido.Connect.Calcom.Webhook` provides HMAC-SHA256 signature verification
against the `x-cal-signature-256` header:

```elixir
# Verify a raw webhook request
{:ok, payload} = Calcom.Webhook.verify_request(body, headers, webhook_secret)

# Verify and normalize into a WebhookDelivery struct
{:ok, %WebhookDelivery{} = delivery} =
  Calcom.Webhook.verify_delivery(body, headers, webhook_secret)
```

Use `verify_delivery/4` from a Plug or Phoenix controller with the raw
request body and webhook secret. The `normalized_signal` field in the
delivery contains the booking event with snake_case keys.

## Live-Test Guidance

The offline test suite exercises every action, trigger, scope, pack, and
naming convention through injected fake clients and does **not** call live
Cal.com APIs. When you need to validate against a real Cal.com account:

1. **Use a dedicated test Cal.com account** — never personal or production
   accounts. Create a separate Cal.com user or organization for testing.

2. **Use an API key for CI and development** — generate a `cal_`-prefixed
   personal access token from the Cal.com developer settings. Store it in an
   environment variable, never in version control.

3. **Scope grants to the least-privilege pack** — start with `:calcom_reader`
   and only escalate to `:calcom_booking`, `:calcom_webhook`, or
   `:calcom_full` as the test scenario demands. Verify that scope-restricted
   connections correctly report `:missing_scopes`.

4. **Exercise the full booking lifecycle** — list event types, create a test
   booking via the Cal.com UI or API, list and get the booking, reschedule it,
   then cancel it.

5. **Exercise the webhook lifecycle** — create a webhook pointing to a test
   endpoint, list webhooks to confirm registration, trigger a booking event,
   verify the delivery payload, then delete the webhook.

6. **Verify trigger signature verification** — confirm that
   `Calcom.Webhook.verify_delivery/4` accepts valid HMAC signatures and
   rejects invalid or missing signatures. Use the webhook secret returned
   by Cal.com during webhook creation.

7. **Do not hardcode tokens** — store API keys and OAuth tokens in environment
   variables or a secrets manager. Never commit access tokens, refresh tokens,
   or client secrets to version control.

8. **Clean up** — delete all test webhooks after each live test run to avoid
   accumulating stale endpoints in the Cal.com account.

## Package Quality Gates

The Cal.com package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_calcom
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_calcom/test --no-deps-check
```
