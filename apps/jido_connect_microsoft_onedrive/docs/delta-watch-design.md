# OneDrive Delta / Watch Design Note

This document outlines approaches for adding change-detection triggers to the
OneDrive connector. The `delta` action handler already provides a working
Microsoft Graph delta query implementation. This note covers how a future
trigger layer could wrap it for continuous polling and push-based patterns.

## Goals

- Detect when OneDrive drive items are created, updated, or deleted.
- Emit normalized signals that downstream consumers can process.
- Integrate with the existing `Jido.Connect` trigger DSL, handler, and
  checkpoint patterns.

## Current State

The connector ships a `delta` action and handler
(`Handlers.Actions.Delta`) that calls the Microsoft Graph
`/me/drive/root/delta` endpoint. It accepts an optional `token` for
incremental sync and returns:

```elixir
%{
  items: [...],
  next_link: "https://graph.microsoft.com/v1.0/...",
  delta_link: "https://graph.microsoft.com/v1.0/...?$deltaToken=...",
  delta_token: "RmFib3V..."
}
```

The `delta_token` (or `delta_link` URL) serves as the resumption checkpoint
for the next incremental sync cycle.

## Approach 1: Delta Token Polling

### Mechanism

Wrap the existing delta handler in a trigger that polls at a configured
interval, persisting the `delta_token` between cycles.

### Trigger DSL Sketch

```elixir
triggers do
  poll :drive_item_changed do
    id("microsoft.onedrive.items.changed")
    resource(:drive_item)
    verb(:watch)
    data_classification(:personal_data)
    label("OneDrive drive item changed")
    description("Poll for OneDrive changes using the Microsoft Graph delta endpoint.")
    interval_ms(300_000)
    checkpoint(:delta_token)
    dedupe(%{key: [:item_id, :last_modified_date_time]})
    handler(Jido.Connect.MicrosoftOnedrive.Handlers.Triggers.DriveItemPoller)

    access do
      auth(:user)
      scopes(["Files.Read"], resolver: Jido.Connect.MicrosoftOnedrive.ScopeResolver)
    end

    config do
      field(:page_size, :integer,
        default: 100,
        description: "Maximum items per delta page."
      )
    end

    signal do
      field(:item_id, :string)
      field(:name, :string)
      field(:change_type, :string)
      field(:parent_reference, :map)
      field(:item, :map)
    end
  end
end
```

### Handler Behavior

1. Read the persisted `delta_token` checkpoint (or omit for initial full sync).
2. Call `Handlers.Actions.Delta.run/2` with the token.
3. Follow `next_link` pages until exhausted.
4. Normalize each changed item through `Normalizer.drive_item/1`.
5. Classify change type from the `@removed` OData annotation (present = deleted).
6. Deduplicate signals by `{item_id, last_modified_date_time}`.
7. Persist the final `delta_token` as the new checkpoint.
8. Return `{:ok, %{signals: signals, checkpoint: new_token}}`.

### Pros

- Uses the existing delta handler — no new Graph API calls.
- Microsoft Graph delta tokens are stable across sessions.
- Initial sync (no token) returns a snapshot of all items; subsequent polls
  return only changes.
- Compatible with all Microsoft 365 plans.

### Cons

- Polling interval introduces latency (5 minutes by default).
- Delta tokens expire after a configurable period (typically 7 days for
  personal OneDrive; longer for SharePoint-backed drives). Expired tokens
  trigger a full resync.
- Large drives may produce many pages per cycle.

## Approach 2: Microsoft Graph Webhooks (Subscriptions)

### Mechanism

Register a Microsoft Graph `subscription` for `driveItem` change notifications.
Microsoft pushes change payloads to a registered HTTPS callback URL when items
are created, updated, or deleted.

### Subscription Resource

```
POST https://graph.microsoft.com/v1.0/subscriptions
{
  "changeType": "updated",
  "notificationUrl": "https://host.example.com/integrations/microsoft/webhook",
  "resource": "/me/drive/root",
  "expirationDateTime": "2026-05-26T00:00:00Z",
  "clientState": "<webhook-signing-secret>"
}
```

### Pros

- Near-real-time change delivery (within seconds).
- Push-based — no polling overhead.
- Microsoft manages retry semantics for failed deliveries.

### Cons

- Requires a publicly accessible HTTPS endpoint with a valid TLS certificate.
- Subscriptions expire (maximum 30 days for drive items) and must be renewed.
- Subscription lifecycle (create, renew, delete) adds operational complexity.
- Notification payloads are lightweight — a separate GET is often needed to
  fetch the full changed item.
- Requires the `Files.ReadWrite` scope for subscription management (not
  `Files.Read`).

### Implementation Notes

- Trigger type would be `webhook`.
- The handler receives and validates the `clientState` signing secret, then
  normalizes the notification payload into a signal.
- A background process manages subscription renewal before expiration.

## Approach 3: Delta Token Polling with Webhook Activation

### Mechanism

Combine both approaches: use a webhook subscription for near-real-time
notifications when available, and fall back to delta token polling when
webhooks are unavailable or expired.

### Recommended Implementation Order

1. **Delta Token Polling** — Implement first. Wraps the existing handler
   with a trigger and checkpoint persistence. Follows established patterns
   from other connectors (HubSpot, Salesforce).

2. **Webhook Subscriptions** — Implement second for hosts that can expose
   a public callback endpoint. Provide subscription lifecycle management
   helpers.

3. **Hybrid** — Implement last for resilient, best-effort change detection.

## Signal Schema

Both approaches should emit signals with a consistent shape:

```elixir
%{
  item_id: "01ABCD1234...",
  name: "Quarterly Report.xlsx",
  change_type: "updated",       # "created" | "updated" | "deleted"
  parent_reference: %{...},
  drive_id: "b!abc123...",
  item: %{...}                  # Normalized DriveItem struct or map
}
```

## Change Type Detection

Microsoft Graph delta responses indicate deleted items with an
`@removed` annotation:

```json
{
  "id": "01ABCD1234...",
  "@removed": {
    "reason": "deleted"
  }
}
```

Items without `@removed` are created or updated. The handler should:

- Check for `"@removed"` → `change_type: "deleted"`
- Compare `created_date_time` and `last_modified_date_time` to distinguish
  `"created"` from `"updated"` when possible.
- Default to `"updated"` when timestamps are identical or unavailable.

## Open Questions

- **Checkpoint persistence**: Should the trigger use the shared
  `Jido.Connect.Checkpoint` behaviour or a OneDrive-specific store?
- **Full resync on token expiry**: Should the trigger emit signals for all
  items during a full resync, or only establish a new checkpoint without
  signals? The established pattern is to establish a checkpoint silently.
- **Multi-drive support**: Should the trigger support monitoring multiple
  drives, or one drive per trigger instance?
- **Webhook subscription management**: Who owns subscription lifecycle — the
  connector package or the host application?
