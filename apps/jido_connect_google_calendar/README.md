# Jido Connect Google Calendar

Google Calendar provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Calendar-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Actions

- `google.calendar.calendar.list`
- `google.calendar.event.list`
- `google.calendar.event.get`
- `google.calendar.event.create`
- `google.calendar.event.update`
- `google.calendar.event.delete`
- `google.calendar.freebusy.query`
- `google.calendar.availability.find`
- `google.calendar.calendar.get`
- `google.calendar.calendar.create`
- `google.calendar.calendar.patch`
- `google.calendar.calendar.update`
- `google.calendar.calendar.delete`
- `google.calendar.calendar.clear`
- `google.calendar.calendar_list.get`
- `google.calendar.calendar_list.create`
- `google.calendar.calendar_list.patch`
- `google.calendar.calendar_list.update`
- `google.calendar.calendar_list.delete`
- `google.calendar.acl.list`
- `google.calendar.acl.get`
- `google.calendar.acl.create`
- `google.calendar.acl.patch`
- `google.calendar.acl.update`
- `google.calendar.acl.delete`
- `google.calendar.event.instances`
- `google.calendar.event.move`
- `google.calendar.event.watch`
- `google.calendar.calendar_list.watch`
- `google.calendar.acl.watch`
- `google.calendar.settings.watch`
- `google.calendar.channel.stop`

## Triggers

- `google.calendar.event.changed`
- `google.calendar.event.changed.push`
- `google.calendar.calendar_list.changed.push`
- `google.calendar.acl.changed.push`
- `google.calendar.setting.changed.push`

The event-change poller initializes by draining `events.list` pages to capture a
`nextSyncToken` without replaying existing history. Later polls use that sync
token, emit normalized event-change signals, and advance the checkpoint.

The webhook triggers normalize Google Calendar channel headers for host-verified
deliveries. Hosts are responsible for token verification, HTTPS delivery, and
channel lifecycle storage.

## Catalog Packs

- `:google_calendar_reader` includes calendar/event reads, freebusy,
  availability, event-change polling, and webhook trigger metadata.
- `:google_calendar_scheduler` adds event create, update, and delete tools for
  scheduling workflows, including event move.
- `:google_calendar_watch` adds event, CalendarList, ACL, settings watch
  creation and channel stop lifecycle actions.
- `:google_calendar_manager` adds calendar CRUD, CalendarList item mutation,
  ACL sharing lifecycle, and destructive calendar management tools.

```elixir
Jido.Connect.Catalog.search_tools("calendar",
  modules: [Jido.Connect.Google.Calendar],
  packs: Jido.Connect.Google.Calendar.catalog_packs(),
  pack: :google_calendar_scheduler
)
```

## Scopes

The connector prefers narrow Calendar scopes:

- `calendar.calendarlist.readonly` for listing visible calendars.
- `calendar.calendars.readonly` for calendar resource metadata reads.
- `calendar.calendars` for calendar create, patch, update, delete, and clear.
- `calendar.calendarlist` for user CalendarList item mutation.
- `calendar.events.readonly` for event reads, polling, and event watch
  channels.
- `calendar.events` for event creation, updates, deletes, and moves.
- `calendar.events.freebusy` or `calendar.freebusy` for free/busy and
  availability helpers.
- `calendar.acls.readonly` for ACL reads and ACL watch channels.
- `calendar.acls` for ACL sharing lifecycle actions.
- `calendar.settings.readonly` for settings watch channels.
