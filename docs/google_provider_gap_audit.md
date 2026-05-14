# Google Provider Gap Audit

This document compares the current Google connector packages against the
official Google REST API surfaces as of May 14, 2026. It builds on
`docs/google_surface_audit.md` and should feed `jido_con-nmq.3`, where the
high-value gaps become concrete Beadwork tickets.

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
| Sheets | Strong single-range read/write and structural batch update coverage. | Spreadsheet create, value batch operations, data-filter operations, developer metadata, sheet copy. | No native Sheets watch surface in the REST reference; Drive file-change triggers can cover spreadsheet file changes. |
| Gmail | Strong metadata, message/thread reads, send, draft create/send, label triage, and poll trigger coverage. | Watch/stop lifecycle, history action, attachments, draft management, batch modify/delete, label get/update/delete, message/thread trash/delete. | Settings and CSE surfaces are large and sensitive; keep them out of default packs. |
| Drive | Strong file metadata/content, basic file writes, permission lifecycle, revision lifecycle, comments/replies, shared-drive lifecycle, service-account profiles, poll trigger coverage, and watch/channel lifecycle metadata. | Labels, about/apps, access proposals/approvals. | No whole-drive count or whole-drive principals endpoint in Drive v3; counts/principals remain composed intents. |
| Calendar | Strong event list/get/create/update/delete, calendar list, free/busy, availability, and poll trigger coverage. | Watch/channel lifecycle, calendar CRUD, calendarList item CRUD, ACLs, event instances/move/quickAdd/import, colors/settings. | Event polling exists; provider push channels should be exposed as lifecycle actions/triggers. |
| Contacts | Strong contact/group read and basic contact/group mutation coverage. | Batch contact operations, directory people, other contacts, group get/delete/member modify, contact photos, sync-token polling trigger. | People API exposes sync tokens for incremental connections but no generic watch endpoint. |

## Sheets

Current package: `jido_connect_google_sheets`

Official REST resources include `spreadsheets`, `spreadsheets.values`,
`spreadsheets.developerMetadata`, and `spreadsheets.sheets`.

### Covered

- `spreadsheets.get`
- `spreadsheets.batchUpdate`
- `spreadsheets.values.get`
- `spreadsheets.values.update`
- `spreadsheets.values.append`
- `spreadsheets.values.clear`
- Sheet add/delete/rename through structural batch update wrappers.

### Missing Provider Operations

| Provider Operation | Candidate Action | Priority | Rationale |
| --- | --- | --- | --- |
| `spreadsheets.create` | `google.sheets.spreadsheet.create` | High | Hosts need to create spreadsheets without dropping to raw Drive file creation plus manual Sheets setup. |
| `spreadsheets.values.batchGet` | `google.sheets.values.batch_get` | High | Common read path for dashboards and sync jobs; safer than repeated single-range calls. |
| `spreadsheets.values.batchUpdate` | `google.sheets.values.batch_update` | High | Common multi-range write path with narrower semantics than broad structural `batch_update`. |
| `spreadsheets.values.batchClear` | `google.sheets.values.batch_clear` | Medium | Completes the value batch family; destructive and should require confirmation. |
| `spreadsheets.getByDataFilter` | `google.sheets.spreadsheet.get_by_data_filter` | Medium | Provider-specific filtered read surface; belongs in Sheets, not core. |
| `spreadsheets.values.*ByDataFilter` | Data-filter value actions | Medium | Useful once provider-specific filter schemas are stable. |
| `spreadsheets.developerMetadata.get/search` | Developer metadata actions | Medium | Important for host-owned tagging and sync correlation. |
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
- `users.messages.list/get/send/modify`
- `users.threads.list/get`
- `users.drafts.create/send`
- `users.labels.list/create`
- Polling trigger over message history.

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `users.watch` / `users.stop` | Gmail watch lifecycle actions and webhook trigger metadata | High | Needed for provider push instead of polling-only message change detection. |
| `users.history.list` | `google.gmail.history.list` | High | Makes checkpoint debugging and host-owned replay more explicit. |
| `users.messages.attachments.get` | `google.gmail.attachment.get` | High | Common read path once message metadata reveals attachments. |
| `users.drafts.list/get/update/delete` | Draft management actions | High | Current package can create/send drafts but cannot review or edit them. |
| `users.messages.batchModify` | `google.gmail.messages.batch_modify` | Medium | Efficient triage for multiple messages; same provider concern as label application. |
| `users.messages.trash/untrash/delete/batchDelete` | Message removal actions | Medium | Useful but destructive; keep out of default packs. |
| `users.threads.modify/trash/untrash/delete` | Thread mutation actions | Medium | Complements current thread reads. |
| `users.labels.get/patch/update/delete` | Label management actions | Medium | Completes label lifecycle beyond list/create. |
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
- `events.list/get/insert/update/delete`
- `freebusy.query`
- Derived availability search over free/busy.
- Polling trigger over event sync tokens.

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `events.watch`, `calendarList.watch`, `acl.watch`, `settings.watch`, `channels.stop` | Calendar watch/channel lifecycle actions plus webhook trigger metadata | High | Complements existing polling with provider push. |
| `calendars.get/insert/patch/update/delete/clear` | Calendar CRUD actions | High | Hosts cannot currently create or manage calendars directly. |
| `calendarList.get/insert/patch/update/delete` | Calendar-list item actions | Medium | Needed for user-specific calendar visibility and settings. |
| `acl.list/get/insert/patch/update/delete` | Calendar ACL actions | Medium | Important for sharing workflows; external-write/destructive risk. |
| `events.instances` | `google.calendar.event.instances` | Medium | Important for recurring event inspection. |
| `events.move` | `google.calendar.event.move` | Medium | Common scheduler operation when moving events between calendars. |
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
- `people.createContact`
- `people.updateContact`
- `people.deleteContact`
- `contactGroups.list`
- `contactGroups.create`
- `contactGroups.update`

### Missing Provider Operations

| Provider Operation | Candidate Action/Trigger | Priority | Rationale |
| --- | --- | --- | --- |
| `people.getBatchGet` | `google.contacts.person.batch_get` | High | Efficient contact hydration after search/list results. |
| `people.batchCreateContacts`, `batchUpdateContacts`, `batchDeleteContacts` | Batch contact mutation actions | High | Important for sync/import workflows; destructive cases require confirmation. |
| `people.listDirectoryPeople`, `people.searchDirectoryPeople` | Directory people actions | High | Common Workspace contact discovery surface not covered by personal contacts. |
| `otherContacts.list/search/copyOtherContactToMyContactsGroup` | Other contacts actions | Medium | Useful for Gmail-discovered contacts and promotion into contacts. |
| `contactGroups.get/batchGet/delete` | Group lifecycle actions | Medium | Completes group management beyond list/create/update. |
| `contactGroups.members.modify` | Group membership action | Medium | Required for contact group assignment. |
| `people.updateContactPhoto/deleteContactPhoto` | Contact photo actions | Low | Useful but content-heavy and likely not default pack material. |
| `people.connections.list` sync token trigger | Contact changed poll trigger | Medium | Existing list response supports incremental sync; expose as host-owned polling trigger. |

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

## Next Beadwork Step

`jido_con-nmq.3` should convert the high-priority and selected medium-priority
rows into package-specific tasks. Avoid creating tickets for every provider
method; create tickets around coherent action families with a clear host value.
