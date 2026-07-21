# CHANGELOG

All notable changes to `jido_connect_microsoft_calendar` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-19

### Added

- Initial scaffold: integration DSL, auth profile reuse from the Microsoft
  foundation package, scope resolver, catalog pack shell, and generated module
  tests.
- Action catalog listing calendar read, write, RSVP, and delete actions.
  Handlers return `{:error, :not_implemented}` until full calendar and event
  actions are added.
- Normalized structs and fixtures for calendars, calendar groups, events,
  attendees, locations, recurrence patterns, free/busy slots, and availability
  results. Body content is summarized without exposing raw HTML/text.
- Full Graph API handler implementations for list calendars, get calendar,
  list events, get event, get schedule (free/busy), find meeting times, create
  event, update event, delete event, cancel event, accept event, decline
  event, and tentatively accept event.
- Scope resolver with least-privilege resolution: reads accept
  Calendars.Read.Shared and Calendars.ReadWrite; writes accept
  Calendars.ReadWrite.Shared.
- Privacy boundary module classifying calendar content and personal data
  fields. Raw body keys (`content`) are filtered during normalization.
- Catalog packs: `:microsoft_calendar_metadata` (read-only list metadata),
  `:microsoft_calendar_triage` (adds detail and availability reads),
  `:microsoft_calendar_write` (adds event create, update, and RSVP),
  `:microsoft_calendar_destructive` (adds event delete and cancel).
- Scope matrix documentation mapping every action to its primary and
  alternative accepted Microsoft Graph calendar scopes.
- Read-only live smoke hooks gated on `MICROSOFT_ACCESS_TOKEN` environment
  variable. Tests exercise list calendars, get calendar, list events, get
  event, and get schedule against the real Graph API without write or
  destructive actions. Fixture ids `MICROSOFT_CALENDAR_ID` and
  `MICROSOFT_EVENT_ID` enable optional detail tests.
- Design notes for subscription/watch/delta features planned for a future
  wave: Graph push subscriptions, delta queries, webhook normalization, and
  planned connector action and trigger surface.
- `.env.example` fixture ids for `MICROSOFT_CALENDAR_ID` and
  `MICROSOFT_EVENT_ID`.
