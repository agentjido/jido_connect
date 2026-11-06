# Jido Connect Google Meet

Google Meet provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Meet-specific DSL, handlers,
schemas, normalized structs, and tests package-local as those surfaces are
added.

## Status

The package declares the provider, the user OAuth profile, the Meet scope
resolver, the generated Jido plugin, normalized Zoi-backed structs, read and
space-creation actions, and one poll trigger for available transcripts.
Workspace Events triggers are later work.

## Normalized Structs

- `Jido.Connect.Google.Meet.Space`
- `Jido.Connect.Google.Meet.ConferenceRecord`
- `Jido.Connect.Google.Meet.Participant`
- `Jido.Connect.Google.Meet.Recording`
- `Jido.Connect.Google.Meet.Transcript`
- `Jido.Connect.Google.Meet.TranscriptEntry`

## OAuth Scopes

The provider declares the shared Google identity scopes plus Meet product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/meetings.space.readonly`
- `https://www.googleapis.com/auth/meetings.space.created`

## Tool Surface

- `google.meet.space.create`
- `google.meet.space.get`
- `google.meet.conference_record.list`
- `google.meet.conference_record.get`
- `google.meet.recording.list`
- `google.meet.recording.get`
- `google.meet.transcript.list`
- `google.meet.transcript.get`
- `google.meet.transcript.entry.list`

The recording actions return metadata only: `recording_name`, `state`,
`start_time`, `end_time` and the Drive destination with `drive_file_id` and
`export_uri`. They do not download the recording media.
`google.meet.transcript.list` and `google.meet.transcript.get` likewise return
metadata without the transcript document.

The recording file is read through the Drive package.
`google.drive.file.download` takes the `drive_file_id` as its `file_id` input
and needs the `drive.readonly` grant; `drive.file` covers only files the app
created or opened. The action buffers the whole file in memory and returns
`file_content`. An MP4 file contains NUL bytes, so `file_content` holds the
recording base64-encoded as `content_base64`, with the byte count of the file
as `size`. Neither package transcodes or otherwise processes media.

The optional `max_bytes` input of `google.drive.file.download` bounds that
buffer for a long recording. A recording with more bytes than `max_bytes`
fails with `reason: :limit_exceeded` and no content. The limit counts the
bytes of the file, not of its base64 text. "Limiting Content Bytes" in
`../jido_connect_google_drive/README.md` describes it.

`google.meet.transcript.entry.list` returns transcript text entry by entry.
Each entry carries its `entry_name`, the speaking `participant` as a
conference participant resource name, `text`, `language_code`, `start_time`
and `end_time`, so a caller can cite an excerpt against its speaker and time.
It pages with `page_size` (default 10; Google returns at most 100 entries per
page) and `page_token`, and resolves `meetings.space.readonly`, or
`meetings.space.created` when the connection holds it.

Google deletes transcript entries 30 days after the conference ends. Entries
come from the transcription itself and can differ from the transcript document
when someone has edited that document.

The transcript document stays readable through the Drive package:
`google.meet.transcript.get` returns its `document_id`, and
`google.drive.file.export` with `mime_type: "text/plain"` exports it. That
route needs the `drive.readonly` grant; `drive.file` covers only files the app
created or opened, which a Meet transcript document is not.

## Transcript Poll Trigger

`google.meet.transcript.available` is a poll trigger with one generated
sensor, `Jido.Connect.Google.Meet.Sensors.TranscriptAvailable`. It runs once
per connection and takes no config. Each poll lists the conference records
that ended at or after the checkpoint's watermark, then lists the transcripts
of every record that is not settled yet. It emits one signal per transcript
in state `FILE_GENERATED` with a non-empty `document_id`:

- `transcript_name`
- `conference_record_name`
- `document_id`
- `state`
- `start_time` and `end_time` of the transcript
- `export_uri` of the transcript document

Signals carry no transcript text. The trigger declares
`interval_ms(300_000)` and `dedupe(%{key: [:transcript_name]})`, and resolves
`meetings.space.readonly`, or `meetings.space.created` when the connection
holds it, like the conference record and transcript reads it calls.

`google.meet.transcript.file_generated` stays reserved for a Workspace Events
trigger.

### Checkpoint

Google Meet has no sync token for conference records or transcripts, so the
checkpoint is synthetic. This deviates from
`../../docs/google_polling_checkpoints.md`, which expects the newest provider
checkpoint. The checkpoint is a JSON string that hosts store as they get it:

```json
{
  "version": 1,
  "watermark": "2026-10-30T16:54:56.856863Z",
  "settled": [
    {
      "name": "conferenceRecords/abc",
      "end_time": "2026-10-30T16:54:56.856863Z"
    }
  ],
  "pending": [
    {
      "name": "conferenceRecords/def",
      "end_time": "2026-10-30T17:19:37.048979Z",
      "emitted": ["conferenceRecords/def/transcripts/ghi"]
    }
  ]
}
```

- `watermark` is a conference end time; the next poll filters on
  `end_time>="<watermark>"`. It moves only over records that need no further
  check. Without pending records it is the latest end time the trigger has
  listed. With pending records it is the latest end time of a record that
  needs no further check and ended before the oldest pending record. It never
  moves back. The inclusive filter lists a record that ended exactly at the
  watermark again, so a second record with the same end time is not lost.
- `settled` lists, by name and end time, the records at or after the
  watermark that need no further check: settled records, and records that
  left the pending set by age or count. A poll skips them, so the repeat with
  the returned checkpoint emits nothing. Entries below the watermark leave the
  list. It is sorted by end time, then name.
- `pending` holds the records that are not settled, with their end time and
  the transcripts already emitted for them. A poll lists their transcripts
  again.

A record is settled when it has at least one transcript and every transcript
is in `FILE_GENERATED` with a `document_id`. A record without transcripts,
for example from a meeting without transcription, stays pending until it
leaves by age. A record with one generated and one unfinished transcript
emits the generated one at once and stays pending; `emitted` keeps the
second poll from emitting it again.

While a pending record holds the watermark, every poll lists all conferences
that ended since then, for at most the 24 hours of the age bound. A meeting
without transcription holds it that long, so in practice each poll lists the
conferences of the last day and skips the known ones. More than 100 of them
exceed the item bound of the conference record list: the poll fails with
`reason: :poll_bound_exceeded` until the host resets the checkpoint. The bound
stays at 100, which is more conferences than one account usually ends in a
day (an assumption, not measured).

### Bounds

- At most 50 pending records. Beyond that, the records with the oldest end
  time leave first. Fifty is far more meetings than one person ends within
  the age bound, so in practice the count bound only caps a burst.
- A pending record leaves 24 hours after its conference ended. Before it
  lists conference records, a poll moves stored pending records past that age
  under `settled`; it neither requests their transcripts nor treats them as
  new records. A record Google no longer serves, for example after deleting
  it 30 days after the conference, therefore does not fail the poll. A record
  listed for the first time after that age is checked once and then leaves.
  Transcripts usually reach `FILE_GENERATED` minutes after a meeting ends (not
  verified live). Twenty-four hours covers long generation delays; the cost is
  one transcript list request per pending record and poll, about 288 a day
  for a meeting without transcription.
- Per poll, at most 10 pages and 100 conference records; per record, at most
  5 pages and 25 transcripts. Both lists request 100 items per page.

A record that leaves by age or count is not checked again, and the watermark
can move past it. A transcript that becomes ready later is not emitted.

### First Poll and Errors

An empty checkpoint, `nil` or `""`, sets the watermark to the current time
and emits nothing, without calling Google. Conferences that ended before the
first poll are not watched, even if their transcripts become ready later.

A poll emits signals and a new checkpoint only after every page of every list
succeeded. A failed page, a repeated `nextPageToken`, a conference record
without an end time or an exceeded page or item bound returns an error and no
checkpoint. Errors that need a reset carry
`details.checkpoint_reset`; an exceeded bound has
`reason: :poll_bound_exceeded`. An unreadable checkpoint returns a validation
error with `reason: :invalid_checkpoint`. After a reset the next poll starts
at the current time again.

A pending record whose transcripts cannot be listed, for example after the
connection lost access to it, fails every poll until it leaves by age.

### Observed Provider Behavior

Checked live on 2026-11-02 against the test account:

- The `end_time` filter compares at microsecond precision: `>=` with a
  record's exact end time lists it, `>` and one microsecond later do not.
- With the `end_time` clause alone, a later page often repeated the first
  record under a fresh page token: in 18 of 23 walks at one record per page.
  The trigger adds `start_time>="1970-01-01T00:00:00Z"`, which every record
  matches; with it, none of 52 walks repeated a record. A poll still drops a
  repeated record and stops at its page bound.

Not verified live: the delay before a finished meeting shows its end time in
the list. The watermark does not pass the end time of a pending record, so a
conference that ends after that record is still found if it appears in the
list before the record leaves the pending set. A conference is missed when it
appears in the list only after a later conference of the same connection needs
no further check, usually because its transcripts are generated, and no
pending record ends before that later conference. The later conference may
have been pending at first.

## Workspace Events Spike

Meet trigger subscriptions should be backed by Google Workspace Events and
host-owned durable state. The design spike for that work lives in
`../../docs/google_meet_workspace_events_spike.md`.

## Catalog Packs

- `:google_meet_reader` exposes metadata-first read actions for spaces,
  conference records, recordings, and transcripts.
- `:google_meet_transcript_reader` is opt-in and adds
  `google.meet.transcript.entry.list`, which returns transcript text, to the
  reader surface. `:google_meet_reader` stays metadata-only.
- `:google_meet_scheduler` adds meeting-space creation to the reader surface.

All packs select actions only. `pack.metadata.triggers` names the poll
trigger `google.meet.transcript.available`, and
`pack.metadata.future_triggers` lists the Workspace Events triggers that wait
for subscription lifecycle and host-owned durable state.

## Tool Availability

Generated plugin availability reports one entry per generated action and
trigger:

```elixir
Jido.Connect.Google.Meet.Plugin.tool_availability(%{connection: connection})
```
