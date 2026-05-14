# Google Meet Workspace Events Spike

Status: design note for `jido_con-9sn.6`. This task documents the event
subscription shape for Google Meet without adding durable persistence, renewal
jobs, or runtime triggers.

## Official Surface

Google Meet events are delivered through the Google Workspace Events API and a
Google Cloud Pub/Sub topic. A subscription is created against a target resource
and event types, then Workspace Events publishes CloudEvents-formatted Pub/Sub
messages to the configured topic.

Required project setup:

- Enable `workspaceevents.googleapis.com`.
- Enable `pubsub.googleapis.com`.
- Create a Pub/Sub topic in the same Google Cloud project used to create the
  Workspace Events subscription.
- Grant the authenticated user OAuth scopes that support the requested Meet
  events: `https://www.googleapis.com/auth/meetings.space.created` or
  `https://www.googleapis.com/auth/meetings.space.readonly`.

Meet target resources:

- Meeting space: `//meet.googleapis.com/spaces/{space_id}`
- User: `//cloudidentity.googleapis.com/users/{user_id}`

A user target receives events for meeting spaces owned by that user. A meeting
space target receives events for that specific space.

Supported Meet event types:

- `google.workspace.meet.conference.v2.started`
- `google.workspace.meet.conference.v2.ended`
- `google.workspace.meet.participant.v2.joined`
- `google.workspace.meet.participant.v2.left`
- `google.workspace.meet.recording.v2.started`
- `google.workspace.meet.recording.v2.ended`
- `google.workspace.meet.recording.v2.fileGenerated`
- `google.workspace.meet.smartNote.v2.started`
- `google.workspace.meet.smartNote.v2.ended`
- `google.workspace.meet.smartNote.v2.fileGenerated`
- `google.workspace.meet.transcript.v2.started`
- `google.workspace.meet.transcript.v2.ended`
- `google.workspace.meet.transcript.v2.fileGenerated`

Known limitation: calendar invitees and participants who are not owners can only
receive `google.workspace.meet.conference.v2.started` and
`google.workspace.meet.transcript.v2.fileGenerated`.

## Subscription Model

Workspace Events `subscriptions.create` requires:

- `targetResource`: full resource name for a Meet space or Cloud Identity user.
- `eventTypes`: one or more supported Meet event type strings.
- `notificationEndpoint.pubsubTopic`: `projects/{project}/topics/{topic}`.

The API also returns subscription state and expiration data. Meet event payloads
should be treated as resource references. Workspace Events `payloadOptions` are
documented as only supported for Chat events, so a Meet trigger should not
assume rich resource payloads.

Subscriptions expire. With resource data omitted, the documented maximum
expiration is seven days. A durable implementation needs renewal before
expiration and handling for lifecycle notifications. This spike intentionally
does not add that storage or renewal loop.

## Proposed jido_connect Shape

Keep the Workspace Events transport shared in the Google foundation package, but
keep Meet trigger declarations and event normalization provider-specific in
`jido_connect_google_meet`.

Shared Google foundation candidate:

- `Jido.Connect.Google.WorkspaceEvents.Client`
- `create_subscription/2`
- `get_subscription/2`
- `list_subscriptions/2`
- `renew_subscription/2`
- `delete_subscription/2`
- `reactivate_subscription/2`
- Pub/Sub CloudEvent decoding helpers

Meet package candidate actions:

- `google.meet.subscription.create`
- `google.meet.subscription.get`
- `google.meet.subscription.list`
- `google.meet.subscription.renew`
- `google.meet.subscription.delete`
- `google.meet.subscription.reactivate`

Meet package candidate triggers:

- `google.meet.conference.started`
- `google.meet.conference.ended`
- `google.meet.participant.joined`
- `google.meet.participant.left`
- `google.meet.recording.started`
- `google.meet.recording.ended`
- `google.meet.recording.file_generated`
- `google.meet.transcript.started`
- `google.meet.transcript.ended`
- `google.meet.transcript.file_generated`

Smart note events are documented by Google, but this package does not yet have
Smart Note structs or actions. Add Smart Note trigger support only after a small
metadata model exists.

## Host-Owned Durable State

Do not make the connector own durable subscription storage. The host application
should persist subscription metadata and provide it back to connector actions or
trigger runtimes.

Minimum future storage fields:

- Google subscription resource name, such as `subscriptions/{subscription}`.
- Target resource and event types.
- Pub/Sub topic.
- Connection id, tenant id, owner id, and authority.
- State, suspension reason, etag, create time, update time, expire time.
- Renewal deadline and last renewal attempt.
- Last Pub/Sub message id or CloudEvent id for deduplication.

This aligns with the existing host-owned storage direction in
`docs/host_owned_storage.md`.

## Event Normalization

A future webhook or Pub/Sub adapter should normalize the incoming CloudEvent
envelope before invoking Jido triggers:

- Preserve CloudEvent `id`, `source`, `type`, `time`, and Pub/Sub message id.
- Map Meet event type to the Jido trigger id.
- Extract resource names from payload keys:
  - `conferenceRecord.name`
  - `participantSession.name`
  - `recording.name`
  - `transcript.name`
  - `smartNote.name`
- Do not fetch recording media, transcript document content, or transcript
  entries during normalization.

Hydration should be opt-in and metadata-only by default:

- Conference events can use `google.meet.conference_record.get`.
- Recording events can use `google.meet.recording.get`.
- Transcript events can use `google.meet.transcript.get`.
- Participant events can be hydrated later after participant/session actions
  exist.

## Implementation Sequence

1. Add a shared Google Workspace Events client in `jido_connect_google`.
2. Add Meet subscription lifecycle actions in `jido_connect_google_meet`.
3. Add a Pub/Sub CloudEvent decoder and Meet event normalizer.
4. Add trigger metadata for conference, participant, recording, and transcript
   events, backed by host-provided subscription records.
5. Add host-facing renewal guidance and tests for lifecycle events.
6. Add live tests only after the project has Pub/Sub and Workspace Events APIs
   enabled and a safe topic/subscription fixture.

## References

- Google Meet event types:
  https://developers.google.com/workspace/events/guides/events-meet
- Workspace Events subscription resource:
  https://developers.google.com/workspace/events/reference/rest/v1/subscriptions
- Creating Workspace Events subscriptions:
  https://developers.google.com/workspace/events/guides/create-subscription
- Workspace Events OAuth scopes:
  https://developers.google.com/workspace/events/guides/auth
- Meet event response model:
  https://developers.google.com/workspace/meet/api/guides/events-overview
