# Google Provider Gap Audit

This document compares the current Google connector packages against the
official Google REST API surfaces as of May 14, 2026. It builds on
`docs/google_surface_audit.md` and records the post-expansion state after the
high-value gaps were converted into Beadwork tickets and implemented.

The goal is connector-specific expansion, not a provider-neutral query DSL in
`jido_connect`. Filtering, field masks, search syntax, data filters, and
provider query languages should remain in each Google package and be modeled
with provider-specific Zoi schemas.

## Sources

Official references used for this comparison:

- Google Sheets API v4 REST reference:
  <https://developers.google.com/workspace/sheets/api/reference/rest>
- Gmail API v1 REST reference:
  <https://developers.google.com/workspace/gmail/api/reference/rest>
- Google Drive API v3 REST reference:
  <https://developers.google.com/workspace/drive/api/reference/rest/v3>
- Google Calendar API v3 REST reference:
  <https://developers.google.com/workspace/calendar/api/v3/reference>
- People API v1 REST reference:
  <https://developers.google.com/people/api/rest>
- Google API discovery documents:
  `https://www.googleapis.com/discovery/v1/apis/<api>/<version>/rest`

## Executive Findings

| Package | Current Shape | High-Value Gaps | Notes |
| --- | --- | --- | --- |
| Sheets | Strong spreadsheet create/read, values read/write/batch, data-filter, developer metadata, and structural batch update coverage. | Sheet copy. | No native Sheets watch surface in the REST reference; Drive file-change triggers can cover spreadsheet file changes. |
| Gmail | Strong metadata, message/thread reads, send, draft lifecycle, label lifecycle, attachments, history, batch triage/delete, watch/stop lifecycle, poll trigger, and webhook trigger metadata coverage. | Settings and specialized import/insert workflows. | Settings and CSE surfaces are large and sensitive; keep them out of default packs. |
| Drive | Strong file metadata/content, basic file writes, permission lifecycle, revision lifecycle, comments/replies, shared-drive lifecycle, service-account profiles, poll trigger coverage, and watch/channel lifecycle metadata. | Labels, about/apps, access proposals/approvals. | No whole-drive count or whole-drive principals endpoint in Drive v3; counts/principals remain composed intents. |
| Calendar | Strong event list/get/create/update/delete/instances/move, calendar and CalendarList lifecycle, ACL lifecycle, free/busy, availability, poll trigger coverage, and watch/channel lifecycle metadata. | Event quickAdd/import, colors, and settings reads. | Event polling and provider push channel metadata now both exist. |
| Contacts | Strong personal contact, batch contact, directory, other-contact, contact-group read/mutation, group membership, and sync-token poll trigger coverage. | Contact photo actions. | People API exposes sync tokens for incremental connections but no generic watch endpoint. |

## Sheets

Current package: `jido_connect_google_sheets`

Official REST resources include `spreadsheets`, `spreadsheets.values`,
`spreadsheets.developerMetadata`, and `spreadsheets.sheets`.

### Covered

- `spreadsheets.create`
- `spreadsheets.get`
- `spreadsheets.getByDataFilter`
- `spreadsheets.batchUpdate`
- `spreadsheets.values.get`
- `spreadsheets.values.batchGet`
- `spreadsheets.values.batchGetByDataFilter`
- `spreadsheets.values.update`
- `spreadsheets.values.append`
- `spreadsheets.values.clear`
- `spreadsheets.values.batchUpdate`
- `spreadsheets.values.batchUpdateByDataFilter`
- `spreadsheets.values.batchClear`
- `spreadsheets.values.batchClearByDataFilter`
- `spreadsheets.developerMetadata.get/search`
- Sheet add/delete/rename through structural batch update wrappers.

### Missing Provider Operations

| Provider Operation | Candidate Action | Priority | Rationale |
| --- | --- | --- | --- |
| `spreadsheets.sheets.copyTo` | `google.sheets.sheet.copy_to` | Low | Useful but less central than value batch and create operations. |

### Trigger Notes

The Sheets REST reference does not expose watch resources. Spreadsheet file
changes should continue to be represented through Drive file-change triggers
when a host needs spreadsheet-level change detection.

## Gmail

Current package: `jido_connect_gmail`

Official REST resources include `users`, `users.messages`, `users.threads`,
`users.drafts`, `users.labels`, `users.history`, attachments, and broad
settings resources.

### Covered

- `users.getProfile`
- `users.watch` / `users.stop`
- `users.history.list`
- `users.messages.list/get/send/modify/batchModify/trash/untrash/delete/batchDelete`
- `users.messages.attachments.get`
- `users.threads.list/get/modify/trash/untrash/delete`
- `users.drafts.list/get/create/update/send/delete`
- `users.labels.list/get/create/update/delete`
- Polling trigger over message history.
- Webhook trigger metadata for Gmail Pub/Sub push notifications.

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `users.settings.*` | Settings action family | Low | Large, sensitive surface. Split into a later explicit Gmail settings epic if needed. |
| `users.messages.import/insert` | Import/insert actions | Low | Specialized migration/admin workflows; avoid default catalog packs. |

## Drive

Current package: `jido_connect_google_drive`

Official REST resources include files, changes, channels, permissions,
revisions, comments, replies, shared drives, apps, labels, access proposals,
and approvals.

### Covered

- `files.list/get/create/copy/update/delete/export/download`
- Folder creation through `files.create`
- `permissions.list/create/get/update/delete`
- `revisions.list/get/update/delete`
- `comments.list/get/create/update/delete`
- `replies.list/get/create/update/delete`
- `drives.list/get/create/update/delete/hide/unhide`
- Polling trigger over `changes`.
- Drive watch/channel lifecycle actions and webhook trigger metadata.

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `files.listLabels/modifyLabels` | File label actions | Medium | Useful for Workspace metadata workflows. |
| `about.get`, `apps.list/get`, `files.generateIds` | Metadata utility actions | Low | Useful for diagnostics and advanced file creation. |
| `files.emptyTrash` | Trash action | Low | Broad destructive operation; keep out of default packs. |
| `accessproposals.*`, `approvals.*` | Access proposal and approval actions | Low | Specialized Workspace workflow surface; likely separate epic. |

### Explicit Non-Gaps

- Whole-drive file counts are not a single Drive v3 endpoint. They remain a
  composed intent over `files.list` pagination.
- Whole-drive distinct principals are not a single Drive v3 endpoint. They
  remain composed over file enumeration plus `permissions.list`.
- Provider query syntax for `files.list(q: ...)` should stay in Drive-specific
  action inputs and Zoi validation.

## Calendar

Current package: `jido_connect_google_calendar`

Official REST resources include ACL, calendarList, calendars, channels, colors,
events, freebusy, and settings.

### Covered

- `calendarList.list`
- `calendarList.get/insert/patch/update/delete`
- `calendars.get/insert/patch/update/delete/clear`
- `acl.list/get/insert/patch/update/delete`
- `events.list/get/insert/update/delete`
- `events.instances`
- `events.move`
- `freebusy.query`
- Derived availability search over free/busy.
- Polling trigger over event sync tokens.
- Watch/channel lifecycle for `events`, `calendarList`, `acl`, `settings`,
  and `channels.stop`.
- Webhook trigger metadata and header normalization for Calendar channel
  notifications.

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `events.quickAdd` | `google.calendar.event.quick_add` | Low | Convenience endpoint, but less predictable for AI-driven hosts. |
| `events.import` | `google.calendar.event.import` | Low | Migration/admin workflow. |
| `colors.get`, `settings.list/get` | Metadata/settings actions | Low | Useful for UI polish and diagnostics. |

## Contacts

Current package: `jido_connect_google_contacts`

Official People API resources include `people`, `people.connections`,
`contactGroups`, `contactGroups.members`, and `otherContacts`.

### Covered

- `people.connections.list`
- `people.get`
- `people.searchContacts`
- `people.getBatchGet`
- `people.batchCreateContacts`
- `people.batchUpdateContacts`
- `people.batchDeleteContacts`
- `people.listDirectoryPeople`
- `people.searchDirectoryPeople`
- `otherContacts.list`
- `otherContacts.search`
- `otherContacts.copyOtherContactToMyContactsGroup`
- `people.createContact`
- `people.updateContact`
- `people.deleteContact`
- `contactGroups.list`
- `contactGroups.get`
- `contactGroups.batchGet`
- `contactGroups.create`
- `contactGroups.update`
- `contactGroups.delete`
- `contactGroups.members.modify`
- `people.connections.list` sync-token polling trigger

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `people.updateContactPhoto/deleteContactPhoto` | Contact photo actions | Low | Useful but content-heavy and likely not default pack material. |

## Catalog Guidance

- Read-only batch and metadata actions should join the package reader packs when
  they do not expose content beyond the existing pack promise.
- Mutating actions should land in writer/manager/scheduler packs only when they
  match the pack name and safety metadata.
- Destructive actions, permission sharing, outbound sends, broad batch updates,
  watch channel lifecycle operations, and admin-like settings should be omitted
  from default packs unless a new pack explicitly names that risk.
- Webhook/watch lifecycle actions should be discoverable via action/trigger
  metadata so host apps can expose provider availability without hardcoded maps.
- Generated plugin `tool_availability/1` is the current availability surface
  for host apps. It reports action and trigger ids with connection, scope, and
  allow-list states without requiring credential leases or provider API calls.

## Next Beadwork Step

`jido_con-5zt.12` closes the current-package expansion by refreshing catalog
packs, package docs, and action availability tests before the new Google product
package epics begin.
