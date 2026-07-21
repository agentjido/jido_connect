# Watch/Checkpoint Persistence Design

Status: design capture for a later persistence milestone.

This document captures the watch and checkpoint persistence requirements across
Gmail, Drive, Calendar, and Meet so that a future milestone can add durable
watch lifecycle management without changing connector package contracts.

## Design Principles

1. Connector packages stay storage-free. They accept checkpoint or channel
   state from the host and return the next value after a provider call.
2. Hosts own all durable persistence: checkpoint values, channel metadata,
   subscription records, and renewal state.
3. The persistence contract should be the same shape regardless of whether the
   provider mechanism is a polling checkpoint, a push notification channel, or
   a Workspace Events subscription.
4. Reset guidance (`Jido.Connect.Google.Checkpoint.reset_guidance/0`) is the
   standard way to tell the host that a stored checkpoint must be cleared and
   re-initialized.

## Persistence Record Shapes

### Poll Checkpoint Record

Every poll trigger needs the host to persist a single checkpoint value between
ticks. The record shape is:

```elixir
%{
  trigger_id: String.t(),
  connection_id: String.t(),
  tenant_id: String.t(),
  checkpoint: String.t() | nil,
  updated_at: DateTime.t()
}
```

- `checkpoint` is `nil` on first run. The poller initializes without replaying
  history and returns the first provider checkpoint for the host to persist.
- The host passes the stored checkpoint on subsequent ticks. The poller drains
  all provider pages and returns the newest checkpoint.
- Expired or invalid checkpoints produce a provider error with
  `reason: :checkpoint_expired` and `checkpoint_reset` guidance. The host
  should clear the stored value and retry.

### Push Channel Record

Push notification channels (Drive and Calendar) need richer durable state
because Google channels expire, carry resource identifiers, and must be
renewed or stopped explicitly.

```elixir
%{
  trigger_id: String.t(),
  connection_id: String.t(),
  tenant_id: String.t(),
  channel_id: String.t(),
  resource_id: String.t(),
  resource_uri: String.t(),
  address: String.t(),
  token: String.t() | nil,
  expiration: String.t() | nil,
  kind: String.t() | nil,
  params: map(),
  metadata: map(),
  state: :active | :expired | :stopped,
  created_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

- The host creates a channel record after a successful `watch_*` action
  returns a `channel` map from the connector.
- The host updates `state` to `:expired` when the channel expiration passes or
  Google returns a `410` on the webhook endpoint.
- The host updates `state` to `:stopped` after a successful `stop_channel`
  action.
- The host runs a renewal job before `expiration` by calling the same `watch_*`
  action again with a new `channel_id`, then atomically replaces the channel
  record.

### Pub/Sub Subscription Record

Gmail push notifications and future Meet Workspace Events subscriptions use
Google Cloud Pub/Sub. The subscription record captures the Google-side
subscription resource and the Pub/Sub topic.

```elixir
%{
  trigger_id: String.t(),
  connection_id: String.t(),
  tenant_id: String.t(),
  topic_name: String.t(),
  subscription_name: String.t() | nil,
  email_address: String.t() | nil,
  last_history_id: String.t() | nil,
  last_message_id: String.t() | nil,
  metadata: map(),
  state: :active | :expired | :stopped,
  created_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

- The host creates the record after a successful `google.gmail.watch.start`
  returns a `watch` map.
- The host updates `last_history_id` and `last_message_id` from incoming
  webhook signals for deduplication.
- The host runs a renewal job before the Gmail watch expiration by calling
  `google.gmail.watch.start` again.

### Workspace Events Subscription Record (Meet)

Meet events are delivered through the Google Workspace Events API with a Google
Cloud Pub/Sub notification endpoint. This combines aspects of both the push
channel and Pub/Sub subscription patterns.

```elixir
%{
  trigger_id: String.t(),
  connection_id: String.t(),
  tenant_id: String.t(),
  subscription_resource: String.t(),
  # e.g. "subscriptions/{id}"
  target_resource: String.t(),
  # e.g. "//meet.googleapis.com/spaces/{space}"
  event_types: [String.t()],
  pubsub_topic: String.t(),
  # e.g. "projects/{project}/topics/{topic}"
  state: :active | :suspended | :expired | :deleted,
  suspension_reason: String.t() | nil,
  etag: String.t() | nil,
  create_time: DateTime.t() | nil,
  update_time: DateTime.t() | nil,
  expire_time: DateTime.t() | nil,
  last_event_id: String.t() | nil,
  last_pubsub_message_id: String.t() | nil,
  renewal_deadline: DateTime.t() | nil,
  last_renewal_attempt: DateTime.t() | nil,
  metadata: map(),
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

- The host creates the record after a successful
  `google.meet.subscription.create` action.
- `renewal_deadline` is the time by which the host must call
  `google.meet.subscription.renew` to prevent expiration.
- The host should run a renewal job that fires well before `expire_time`,
  using `renewal_deadline` as the scheduling anchor.
- Google Workspace Events subscriptions expire within seven days when
  `payloadOptions` are omitted for Meet. The renewal interval must be shorter
  than this window.

## Product-Specific Requirements

### Gmail

| Aspect | Detail |
|--------|--------|
| Poll trigger | `google.gmail.message.received` |
| Poll checkpoint | `historyId` (string). Initial poll returns current historyId. Subsequent polls drain history since the stored historyId. |
| Poll expiration | Gmail returns `404` when a stored `historyId` is too old. `Checkpoint.expired/4` produces `reason: :checkpoint_expired` with reset guidance. |
| Push trigger | `google.gmail.mailbox.changed` |
| Push mechanism | Gmail `watch` API registers a Cloud Pub/Sub topic. Google publishes push messages containing `emailAddress` and `historyId`. |
| Push lifecycle actions | `google.gmail.watch.start`, `google.gmail.watch.stop` |
| Push expiration | Gmail watches expire. The response includes an `expiration` timestamp. Hosts must renew before expiration. |
| Push dedupe | By `history_id` from the Pub/Sub message. |
| Push verification | `google_pubsub_push` with OIDC verification; host-verified. |
| Persistence needed | Poll: checkpoint record. Push: Pub/Sub subscription record with `last_history_id` for dedup. |

### Drive

| Aspect | Detail |
|--------|--------|
| Poll trigger | `google.drive.file.changed` |
| Poll checkpoint | `pageToken` / `startPageToken` (string). Initial poll uses `changes.getStartPageToken` implicitly. Subsequent polls drain changes since the stored token. |
| Poll expiration | Drive returns `410` when a stored `pageToken` is too old. `Checkpoint.expired/4` produces `reason: :checkpoint_expired` with reset guidance. |
| Push trigger | `google.drive.file.changed.push` |
| Push mechanism | Drive `watch`/`changes.watch` creates a push notification channel. Google sends webhook requests with `X-Goog-*` headers on each resource change. |
| Push lifecycle actions | `google.drive.changes.watch`, `google.drive.file.watch`, `google.drive.channel.stop` |
| Push expiration | Drive channels carry an `expiration` timestamp. Default is approximately one hour unless a longer `expiration_ms` is requested. Maximum is approximately one week. |
| Push dedupe | By `channel_id`, `resource_id`, and `message_number` from `X-Goog-*` headers. |
| Push verification | `google_drive_channel` with host-verified token and `x_goog_channel` headers. |
| Push sync message | The first channel notification has `resource_state: "sync"`. This confirms channel creation and is not a data change (`resource_changed: false`). Hosts should persist the channel metadata from this sync message. |
| Persistence needed | Poll: checkpoint record. Push: channel record with full channel metadata for renewal and stop. |

### Calendar

| Aspect | Detail |
|--------|--------|
| Poll trigger | `google.calendar.event.changed` |
| Poll checkpoint | `syncToken` (string). Initial poll returns a `nextSyncToken`. Subsequent polls use the stored token for incremental sync. |
| Poll expiration | Calendar returns `410` when a `syncToken` is too old. `Checkpoint.expired/4` produces `reason: :checkpoint_expired` with reset guidance. |
| Push triggers | `google.calendar.event.changed.push`, `google.calendar.calendar_list.changed.push`, `google.calendar.acl.changed.push`, `google.calendar.setting.changed.push` |
| Push mechanism | Calendar `watch` creates a push notification channel per resource type (events, calendarList, acl, settings). Google sends webhook requests with `X-Goog-*` headers. |
| Push lifecycle actions | `google.calendar.event.watch`, `google.calendar.calendar_list.watch`, `google.calendar.acl.watch`, `google.calendar.settings.watch`, `google.calendar.channel.stop` |
| Push expiration | Calendar channels support `ttl_seconds` or `expiration_ms`. Maximum TTL is approximately one year, but hosts should renew well before expiration to avoid gaps. |
| Push dedupe | By `channel_id`, `resource_id`, and `message_number` from `X-Goog-*` headers. |
| Push verification | `google_calendar_channel` with host-verified token and `x_goog_channel` headers. |
| Push sync message | Same as Drive: `resource_state: "sync"` confirms creation. Hosts should persist channel metadata from this sync message. |
| Multiple calendars | Each calendar ID needs its own watch channel for events. CalendarList, ACL, and settings watches are per-user, not per-calendar. Hosts must persist a channel record per `calendar_id` for event watches. |
| Persistence needed | Poll: checkpoint record per `calendar_id`. Push: channel record per watched resource (events per calendar, calendarList, acl per calendar, settings). |

### Meet

| Aspect | Detail |
|--------|--------|
| No poll trigger | Meet does not have a poll trigger. All real-time Meet events require Workspace Events subscriptions. |
| Push mechanism | Workspace Events API `subscriptions.create` registers a target resource and event types against a Google Cloud Pub/Sub topic. Google publishes CloudEvent-formatted messages. |
| Target resources | `//meet.googleapis.com/spaces/{space_id}` for a specific space, or `//cloudidentity.googleapis.com/users/{user_id}` for all spaces owned by a user. |
| Event types | `conference.v2.started`, `conference.v2.ended`, `participant.v2.joined`, `participant.v2.left`, `recording.v2.*`, `transcript.v2.*`, `smartNote.v2.*`. |
| Subscription lifecycle actions | `google.meet.subscription.create`, `google.meet.subscription.get`, `google.meet.subscription.list`, `google.meet.subscription.renew`, `google.meet.subscription.delete`, `google.meet.subscription.reactivate` (to be implemented in `jido_connect_google_meet`). |
| Subscription expiration | Maximum seven days when `payloadOptions` are omitted for Meet. Requires frequent renewal. |
| Subscription states | `ACTIVE`, `SUSPENDED`, `DELETED`. Hosts should track `state`, `suspension_reason`, and `expire_time`. |
| Push dedupe | By CloudEvent `id` and Pub/Sub message ID. |
| Push verification | Pub/Sub push with OIDC verification, same as Gmail. |
| Event normalization | Incoming CloudEvent envelopes carry resource names only (no rich payload). Hydration requires calling back to Meet API actions (`conference_record.get`, `recording.get`, `transcript.get`). |
| Persistence needed | Workspace Events subscription record per target resource and event type combination. Renewal job scheduling anchored to `renewal_deadline`. |

## Host Renewal Job Requirements

A future persistence milestone should provide guidance for host renewal jobs:

| Product | Renewal trigger | Renewal action | Maximum window | Recommended renewal margin |
|---------|----------------|----------------|----------------|---------------------------|
| Gmail watch | Before `expiration` from `Watch` response | `google.gmail.watch.start` | ~7 days | Renew at 80% of expiration |
| Drive channel | Before `expiration` from `Channel` response | Same `watch_*` action with new `channel_id` | ~1 week (configurable) | Renew at 80% of expiration |
| Calendar channel | Before `expiration` from `Channel` response | Same `watch_*` action with new `channel_id` | ~1 year (configurable) | Renew at 80% of TTL |
| Meet subscription | Before `expire_time` from subscription resource | `google.meet.subscription.renew` | 7 days | Renew at 50% of window (aggressive) |

Renewal is not automatic in connector packages. The host schedules the job,
calls the renewal action, and atomically replaces the persisted record. If the
renewal action fails, the host should retry with backoff up to the expiration
deadline.

## Host Recovery Procedures

### Expired Checkpoint

1. Poll action returns `{error, %ProviderError{reason: :checkpoint_expired}}`.
2. Host reads `checkpoint_reset` from `error.details`.
3. Host clears the stored checkpoint.
4. Host re-runs the poll. The poller initializes from the provider's current
   cursor without replaying older history.

### Expired Channel or Subscription

1. The renewal job detects that `expiration` or `expire_time` has passed, or
   the provider returns an error indicating the channel/subscription is gone.
2. Host creates a new channel or subscription by calling the start/watch action
   again.
3. Host atomically replaces the persisted record with the new channel or
   subscription metadata.
4. During the gap between expiration and renewal, push notifications are lost.
   Hosts should document this gap and consider combining push triggers with
   periodic poll fallbacks.

### Suspended Workspace Events Subscription

1. Google may suspend a subscription (e.g., due to webhook delivery failures).
2. Host detects `state: :suspended` from `google.meet.subscription.get` or
   lifecycle notification.
3. Host calls `google.meet.subscription.reactivate` if the root cause is
   resolved.
4. If reactivation fails, host deletes the subscription and creates a new one.

## Connector Package Boundaries

The following responsibilities belong to connector packages today and should not
shift to the persistence layer:

- Declaring trigger IDs, checkpoint fields, dedupe keys, and signal schemas in
  Spark DSL fragments.
- Normalizing provider responses into Zoi structs (`Channel`, `Watch`) and
  signal maps.
- Producing `checkpoint_reset` guidance through
  `Jido.Connect.Google.Checkpoint`.
- Validating input (channel_id length, HTTPS address, required fields).
- Mapping provider errors to sanitized `Jido.Connect.Error` values.

The following responsibilities belong to the host persistence layer:

- Storing checkpoint values between poll ticks.
- Storing channel and subscription metadata between watch lifecycle events.
- Scheduling renewal jobs.
- Deduplicating webhook deliveries using persisted dedup keys.
- Detecting and recovering from expired channels and subscriptions.
- Providing checkpoint and channel state back to connector actions and triggers
  at runtime.

## Implementation Sequence

When the persistence milestone is ready:

1. Define a host-facing persistence behaviour or protocol that covers all four
   record shapes (poll checkpoint, push channel, Pub/Sub subscription, and
   Workspace Events subscription).
2. Add a demo implementation using Ecto in the `dev/demo` host app.
3. Add renewal job scheduling in the demo host (e.g., Quantum or Oban).
4. Add integration tests in the demo host that exercise the full lifecycle:
   start watch → receive push → renew → receive push → expire → recover.
5. Document the host contract and renewal guidance in the Google foundation
   README.

## References

- `docs/google_polling_checkpoints.md` — current polling checkpoint contract.
- `docs/google_meet_workspace_events_spike.md` — Meet Workspace Events spike.
- `docs/host_owned_storage.md` — host-owned storage principle.
- `docs/google_extension_patterns.md` — trigger and action extension guide.
- `apps/jido_connect_google/lib/jido_connect/google/checkpoint.ex` — shared
  checkpoint error helpers.
- `apps/jido_connect_google_drive/lib/jido_connect/google/drive/channel.ex` —
  normalized Drive channel struct.
- `apps/jido_connect_gmail/lib/jido_connect/gmail/watch.ex` — normalized Gmail
  watch response struct.
