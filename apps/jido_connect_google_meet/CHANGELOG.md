# Changelog

## Unreleased

- Add the poll trigger `google.meet.transcript.available`, which signals each
  transcript once it reaches `FILE_GENERATED` with a Docs document. It polls
  per connection with a synthetic checkpoint: a watermark on conference end
  times plus pending records, bounded to 50 records and 24 hours. Catalog pack
  metadata names it under `triggers`.
- Add `google.meet.transcript.entry.list`, which lists transcript text entry by
  entry with participant, language code and start and end time, the
  `Jido.Connect.Google.Meet.TranscriptEntry` struct, and the opt-in
  `:google_meet_transcript_reader` catalog pack. `:google_meet_reader` stays
  metadata-only.
- Add `google.meet.participant.list` and `google.meet.participant.get`, which
  resolve the participant that a transcript entry names as its speaker into
  `Jido.Connect.Google.Meet.Participant` with `user_type`, `display_name` and,
  for a signed-in user, `user`. Both join `:google_meet_transcript_reader`.

## 0.1.0

- Add the Google Meet provider package scaffold for Jido Connect.
