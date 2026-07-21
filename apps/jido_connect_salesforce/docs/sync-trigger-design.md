# Salesforce Sync Trigger Design Note

This document outlines three approaches for adding change-detection triggers
to the Salesforce connector. No trigger fragments are implemented yet; this
serves as a planning reference for future waves.

## Goals

- Detect when Salesforce CRM objects (contacts, leads, opportunities, tasks,
  accounts) are created, updated, or deleted.
- Emit normalized signals that downstream consumers can process.
- Integrate with the existing `Jido.Connect` trigger DSL, handler, and
  checkpoint patterns established by the HubSpot connector.

## Approach 1: SOQL Timestamp Polling

### Mechanism

Use `LastModifiedDate` as a checkpoint field. On each poll cycle, issue a SOQL
query like:

```sql
SELECT Id, Name, LastModifiedDate
FROM Contact
WHERE LastModifiedDate > :checkpoint
ORDER BY LastModifiedDate ASC
LIMIT 500
```

The handler stores the latest `LastModifiedDate` from the response as the
next checkpoint.

### Pros

- Works with any Salesforce edition (no add-ons required).
- Only requires the `api` OAuth scope.
- Follows the same pattern as HubSpot contact/deal pollers.

### Cons

- Polling interval introduces latency (e.g., 5 minutes).
- SOQL `WHERE LastModifiedDate > :ts` can miss records that share the same
  millisecond timestamp as the checkpoint. Mitigate with `>=` and dedup.
- Not suitable for high-volume or near-real-time use cases.

### Recommended Configuration

```elixir
triggers do
  poll :contact_changed do
    id("salesforce.contacts.contact.changed")
    resource(:contact)
    verb(:watch)
    data_classification(:personal_data)
    label("Contact changed")
    description("Poll Salesforce for contact changes using LastModifiedDate checkpoints.")
    interval_ms(300_000)
    checkpoint(:last_modified_date)
    dedupe(%{key: [:contact_id, :updated_at]})
    handler(Jido.Connect.Salesforce.Handlers.Triggers.ContactChangedPoller)

    access do
      auth(:oauth2_connected_app)
      scopes(["api"], resolver: Jido.Connect.Salesforce.ScopeResolver)
    end

    config do
      field(:soql_fields, {:array, :string},
        default: ["Id", "FirstName", "LastName", "Email", "LastModifiedDate"],
        description: "Fields to include in the SOQL SELECT clause."
      )

      field(:limit, :integer,
        default: 500,
        description: "Maximum records per poll cycle."
      )
    end

    signal do
      field(:contact_id, :string)
      field(:first_name, :string)
      field(:last_name, :string)
      field(:email, :string)
      field(:change_type, :string)
      field(:updated_at, :string)
      field(:contact, :map)
    end
  end
end
```

### Handler Sketch

The poller handler should:

1. Resolve the client from credentials (`Client.resolve/1`).
2. If no checkpoint exists, perform an initial full scan to establish the
   baseline checkpoint without emitting signals.
3. On subsequent polls, issue a SOQL query filtered by `LastModifiedDate`.
4. Normalize each record using `Normalizer.contact/1` (or the relevant
   resource normalizer).
5. Deduplicate signals by `{record_id, updated_at}`.
6. Return `{:ok, %{signals: signals, checkpoint: new_checkpoint}}`.

## Approach 2: Salesforce Change Data Capture (CDC) Streaming

### Mechanism

Salesforce Change Data Capture emits change events for supported objects
through a streaming API. Events are delivered via the Bayeux/CometD protocol
to a streaming channel (e.g., `/data/ChangeEvents`).

### Pros

- Near-real-time change delivery.
- Includes change type (create, update, delete) and changed fields.
- Native Salesforce feature (no custom Apex required).

### Cons

- Requires Streaming API support (available in Enterprise Edition and above).
- Requires the `api` scope plus potentially `cdp_api` for some objects.
- Change events have a retention window (default 72 hours).
- Commodity and custom objects may not be CDC-enabled without configuration.
- CometD/Bayeux protocol requires a persistent connection or long-polling
  implementation, which differs from the simpler HTTP request/response model
  used elsewhere in the connector.

### Implementation Notes

- Trigger type would be `stream` (or a new `cdc` type) rather than `poll`
  or `webhook`.
- The handler would connect to the Salesforce Streaming API endpoint,
  subscribe to change event channels, and process incoming change events.
- Requires the connector to manage a long-lived HTTP connection.
- Consider using `Req` with streaming or a dedicated process to maintain
  the Bayeux connection.

## Approach 3: Outbound Message (Workflow / Process Builder Webhook)

### Mechanism

Configure Salesforce workflow rules or Process Builder to send outbound
messages (SOAP) or call an external REST endpoint (via Flow or Apex) when
records change. The connector exposes a webhook receiver endpoint.

### Pros

- Near-real-time, push-based.
- Works with all Salesforce editions that support workflow or Flow.
- No polling overhead.

### Cons

- Requires per-object configuration in Salesforce setup (workflow rules,
  flows, or Apex triggers).
- SOAP outbound messages have a fixed schema; REST webhooks require custom
  Apex or Flow configuration.
- Salesforce does not guarantee delivery ordering.
- Retry semantics are managed by Salesforce (up to 24 hours for outbound
  messages).
- Signature verification differs from standard HMAC patterns.

### Implementation Notes

- Trigger type would be `webhook`.
- The handler would receive and validate the webhook payload, then normalize
  it into a signal.
- Verification would use Salesforce's outbound message signing or a shared
  secret configured in the webhook setup.

## Recommended Implementation Order

1. **SOQL Timestamp Polling** — Implement first for contacts, then extend to
   leads, opportunities, and accounts. Follows established patterns from the
   HubSpot connector and works with all Salesforce editions.

2. **Webhook / Outbound Message** — Implement second for scenarios requiring
   lower latency. Provide guidance for Salesforce Flow or Apex configuration.

3. **CDC Streaming** — Implement last for Enterprise+ customers who need
   real-time streaming. May require a new trigger type in the DSL.

## Signal Schema

All three approaches should emit signals with a consistent shape:

```elixir
%{
  record_id: "0035g00000ABCdE",
  sobject_type: "Contact",
  change_type: "updated",       # "created" | "updated" | "deleted"
  changed_fields: ["Email", "Phone"],
  updated_at: "2026-05-16T10:30:00.000Z",
  record: %{...}                 # Normalized record struct or map
}
```

## Open Questions

- **Polling interval**: What is the minimum acceptable polling interval?
  5 minutes is the HubSpot default; Salesforce API limits may allow shorter
  intervals.
- **Initial backfill**: Should the first poll emit signals for all existing
  records, or only establish a checkpoint? The HubSpot pattern establishes a
  checkpoint without emitting signals.
- **Multi-object polling**: Should a single poller query multiple SObject types,
  or should each object type have its own poller? Separate pollers are simpler
  but may consume more API calls.
- **CDC event replay**: How should the connector handle replay after a
  disconnection? CDC events have a 72-hour retention window.
- **Rate limits**: Salesforce enforces API request limits per org. Polling
  frequency must be balanced against other API usage.
