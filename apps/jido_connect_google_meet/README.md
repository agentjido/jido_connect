# Jido Connect Google Meet

Google Meet provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Meet-specific DSL, handlers,
schemas, normalized structs, and tests package-local as those surfaces are
added.

## Status

This scaffold declares the provider package, user OAuth profile, Meet scope
resolver, generated Jido plugin shell, and normalized Zoi-backed structs.
Trigger work is intentionally split into later roadmap tasks.

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

No Meet triggers are exposed yet. The generated plugin and provider metadata
are present so later tasks can add action families without changing package
wiring.

The recording actions, `google.meet.transcript.list` and
`google.meet.transcript.get` expose metadata only. They do not download
recording media or the transcript document.

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

All packs are action-first and mark Workspace Events triggers as later work.
They do not expose trigger ids until subscription lifecycle and host-owned
durable state are implemented.

## Tool Availability

Generated plugin availability is available from the scaffold and will report
one entry per generated action or trigger as those tools are added:

```elixir
Jido.Connect.Google.Meet.Plugin.tool_availability(%{connection: connection})
```
