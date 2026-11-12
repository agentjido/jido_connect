# Changelog

## Unreleased

- `google.calendar.event.changed` returns an `:invalid_response` provider error
  with checkpoint reset guidance when the last page of an incremental poll has
  no `nextSyncToken`. It used to return the poll's own sync token as the next
  checkpoint, as if the poll had succeeded.

## 0.1.0

- Initial Google Calendar provider package scaffold.
