# Google Surface Audit

This document captures the current Google connector surface from the compiled
integration specs as of May 14, 2026, summarizes the provider API gaps, and
records the implementation sequence for the next Google connector work.

Detailed provider comparison lives in `docs/google_provider_gap_audit.md`.
This document is the G13 roll-up: current coverage, gap recommendations,
live-test readiness, and Beadwork sequencing.

## Beadwork Plan

| Ticket | Purpose |
| --- | --- |
| `jido_con-nmq.1` | Capture current Google action and trigger matrix. |
| `jido_con-nmq.2` | Compare current packages against provider APIs. |
| `jido_con-nmq.3` | Create follow-up tickets for current package gaps. |
| `jido_con-nmq.4` | Write final Google surface audit document. |
| `jido_con-nmq.5` | Reconcile cross-Google hardening dependencies. |

## Audit Outputs

| Artifact | Purpose |
| --- | --- |
| `docs/google_surface_audit.md` | Roll-up document for current surface, recommendations, readiness, and sequencing. |
| `docs/google_provider_gap_audit.md` | Detailed comparison against official Google REST resources. |
| `jido_con-5zt` | Existing-package expansion epic generated from the provider gap audit. |

## Current Packages

| Package | Provider ID | Actions | Triggers | Catalog Packs | Auth Profiles |
| --- | --- | ---: | ---: | ---: | --- |
| `jido_connect_google_sheets` | `google_sheets` | 9 | 0 | 2 | `user` |
| `jido_connect_gmail` | `gmail` | 11 | 1 | 3 | `user` |
| `jido_connect_google_drive` | `google_drive` | 14 | 2 | 3 | `user`, `service_account`, `domain_delegated_service_account` |
| `jido_connect_google_calendar` | `google_calendar` | 8 | 1 | 2 | `user` |
| `jido_connect_google_contacts` | `google_contacts` | 9 | 0 | 2 | `user` |

## Cross-Package Notes

- Poll triggers currently exist for Gmail, Drive, and Calendar only. Gmail and
  Drive also expose webhook trigger metadata for provider push deliveries.
- Drive is the only package that declares service-account and delegated
  service-account auth profiles.
- Mutating write actions consistently require AI confirmation, destructive
  actions require `confirmation: :always`, and external writes require explicit
  confirmation.
- Read actions split between metadata-only and content/personal-data scopes.
- Catalog packs are curated safety surfaces. Destructive deletes, broad batch
  updates, permission sharing, and outbound sends are intentionally excluded
  from default writer or reader packs unless the pack explicitly represents that
  risk.
- This inventory is credential-free. Live API coverage remains a separate
  release-readiness step.

## Gap Recommendations

The highest-value follow-up work should be implemented as provider-specific
action families. Do not move Google filter/query semantics into
`jido_connect` core.

| Package | Recommended Expansion |
| --- | --- |
| Sheets | Spreadsheet create, value batch operations, data-filter operations, developer metadata, and sheet copy. |
| Gmail | Watch/stop lifecycle, explicit history action, attachments, draft lifecycle, batch message triage, label lifecycle, and destructive message/thread operations outside default packs. |
| Drive | Revisions, permission lifecycle, comments/replies, shared drives, file labels, and further channel renewal helpers as host patterns emerge. |
| Calendar | Watch/channel lifecycle, calendar CRUD, calendar-list item CRUD, ACL lifecycle, event instances, and event move. |
| Contacts | Batch contact operations, directory people, other contacts, group lifecycle, group membership, and sync-token polling trigger. |

Explicit non-goals from the audit:

- No provider-neutral structured query/filter compiler in `jido_connect`.
- No fake whole-drive stats endpoint. Counts remain composed over
  provider pagination.
- No fake whole-drive principals endpoint. Principal discovery remains composed
  over file enumeration plus permission listing.
- No default catalog exposure for destructive, broad batch, permission-sharing,
  outbound-send, webhook lifecycle, or admin-like settings surfaces.

## Live-Test Readiness

The current package tests remain offline and credential-free. Live checks should
be a separate release-readiness activity once the Google package wave is ready
for a wholesale pass.

| Package | Current Live Scope Needs | Readiness Notes |
| --- | --- | --- |
| Sheets | `spreadsheets.readonly`, `spreadsheets` | Existing reads/writes are ready for live smoke tests against a disposable spreadsheet. |
| Gmail | `gmail.metadata`, `gmail.labels`, `gmail.modify`, `gmail.compose`, `gmail.send`, `https://mail.google.com/` | Sending and destructive mailbox actions need isolated test accounts and explicit confirmation. Permanent message/thread deletes require the full Gmail mailbox scope. |
| Drive | `drive.metadata.readonly`, `drive.readonly`, `drive.file` | Current user OAuth flow is ready; service-account and delegated flows need separate live coverage. |
| Calendar | `calendar.calendarlist.readonly`, `calendar.events.readonly`, `calendar.events`, `calendar.events.freebusy` | Use a disposable calendar for event mutation and delete checks. |
| Contacts | `profile`, `contacts.readonly`, `contacts` | Use a test contact/group namespace to avoid mutating real address book data. |

## Implementation Sequence

1. Finish G13 by reconciling dependencies in `jido_con-nmq.5`.
2. Work the existing-package expansion epic `jido_con-5zt` in dependency order:
   Sheets, Gmail, Drive, Calendar, Contacts, then catalog/docs/tests.
3. Continue the new Google package epics after the audit gate:
   Meet, Analytics, Search Console, Docs, Slides, Forms, and Tasks.
4. Keep `jido_con-jxj` as the final cross-Google hardening and demo gate after
   existing-package expansion and new product packages land.

## Sheets

Package: `jido_connect_google_sheets`

Provider ID: `google_sheets`

Auth profiles: `user`

### Actions

| ID | Risk | Data | Scope | Required Inputs | Output |
| --- | --- | --- | --- | --- | --- |
| `google.sheets.spreadsheet.get` | read | `workspace_metadata` | `spreadsheets.readonly` | `spreadsheet_id` | `spreadsheet` |
| `google.sheets.values.get` | read | `workspace_content` | `spreadsheets.readonly` | `spreadsheet_id`, `range` | `value_range` |
| `google.sheets.values.update` | write | `workspace_content` | `spreadsheets` | `spreadsheet_id`, `range`, `values` | `update` |
| `google.sheets.values.append` | write | `workspace_content` | `spreadsheets` | `spreadsheet_id`, `range`, `values` | `update` |
| `google.sheets.values.clear` | destructive | `workspace_content` | `spreadsheets` | `spreadsheet_id`, `range` | `update` |
| `google.sheets.sheet.add` | write | `workspace_metadata` | `spreadsheets` | `spreadsheet_id`, `title` | `sheet` |
| `google.sheets.sheet.delete` | destructive | `workspace_metadata` | `spreadsheets` | `spreadsheet_id`, `sheet_id` | `result` |
| `google.sheets.sheet.rename` | write | `workspace_metadata` | `spreadsheets` | `spreadsheet_id`, `sheet_id`, `title` | `sheet` |
| `google.sheets.batch_update` | destructive | `workspace_content` | `spreadsheets` | `spreadsheet_id`, `requests` | `batch_update` |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_sheets_readonly` | Spreadsheet metadata and value reads. |
| `google_sheets_writer` | Read-only actions plus value update, append, clear, sheet add, sheet delete, and sheet rename. |

### Triggers

No trigger specs are currently exposed.

## Gmail

Package: `jido_connect_gmail`

Provider ID: `gmail`

Auth profiles: `user`

### Actions

| ID | Risk | Data | Scope | Required Inputs | Output |
| --- | --- | --- | --- | --- | --- |
| `google.gmail.profile.get` | read | `personal_data` | `gmail.metadata` | none | `profile` |
| `google.gmail.labels.list` | read | `personal_data` | `gmail.metadata` | none | `labels` |
| `google.gmail.label.get` | read | `personal_data` | `gmail.readonly` | `label_id` | `label` |
| `google.gmail.messages.list` | read | `message_content` | `gmail.metadata` | none | `messages`, `next_page_token`, `result_size_estimate` |
| `google.gmail.message.get` | read | `message_content` | `gmail.metadata` | `message_id` | `message` |
| `google.gmail.threads.list` | read | `message_content` | `gmail.metadata` | none | `threads`, `next_page_token`, `result_size_estimate` |
| `google.gmail.thread.get` | read | `message_content` | `gmail.metadata` | `thread_id` | `thread` |
| `google.gmail.drafts.list` | read | `message_content` | `gmail.compose` | none | `drafts`, `next_page_token`, `result_size_estimate` |
| `google.gmail.draft.get` | read | `message_content` | `gmail.compose` | `draft_id` | `draft` |
| `google.gmail.history.list` | read | `message_content` | `gmail.metadata` | `start_history_id` | `history`, `next_page_token`, `history_id` |
| `google.gmail.message.attachment.get` | read | `message_content` | `gmail.readonly` | `message_id`, `attachment_id` | `attachment` |
| `google.gmail.message.send` | external_write | `message_content` | `gmail.send` | `to`, `subject` | `message` |
| `google.gmail.draft.create` | write | `message_content` | `gmail.compose` | `to`, `subject` | `draft` |
| `google.gmail.draft.update` | write | `message_content` | `gmail.compose` | `draft_id`, `to`, `subject` | `draft` |
| `google.gmail.draft.send` | external_write | `message_content` | `gmail.compose` | `draft_id` | `message` |
| `google.gmail.draft.delete` | destructive | `message_content` | `gmail.compose` | `draft_id` | `result` |
| `google.gmail.label.create` | write | `personal_data` | `gmail.labels` | `name` | `label` |
| `google.gmail.label.update` | write | `personal_data` | `gmail.labels` | `label_id` | `label` |
| `google.gmail.label.delete` | destructive | `personal_data` | `gmail.labels` | `label_id` | `result` |
| `google.gmail.message.labels.apply` | write | `message_content` | `gmail.modify` | `message_id` | `message` |
| `google.gmail.messages.batch_modify` | write | `message_content` | `gmail.modify` | `message_ids` | `result` |
| `google.gmail.message.trash` | destructive | `message_content` | `gmail.modify` | `message_id` | `message` |
| `google.gmail.message.untrash` | write | `message_content` | `gmail.modify` | `message_id` | `message` |
| `google.gmail.message.delete` | destructive | `message_content` | `https://mail.google.com/` | `message_id` | `result` |
| `google.gmail.messages.batch_delete` | destructive | `message_content` | `https://mail.google.com/` | `message_ids` | `result` |
| `google.gmail.thread.modify` | write | `message_content` | `gmail.modify` | `thread_id` | `thread` |
| `google.gmail.thread.trash` | destructive | `message_content` | `gmail.modify` | `thread_id` | `thread` |
| `google.gmail.thread.untrash` | write | `message_content` | `gmail.modify` | `thread_id` | `thread` |
| `google.gmail.thread.delete` | destructive | `message_content` | `https://mail.google.com/` | `thread_id` | `result` |

### Trigger

| ID | Kind | Checkpoint | Dedupe | Scope | Signal |
| --- | --- | --- | --- | --- | --- |
| `google.gmail.message.received` | poll | `history_id` | `message_id` | `gmail.metadata` | `message_id`, `thread_id`, `history_id`, labels, snippet, headers, message |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_gmail_metadata` | Profile, label list, message/thread reads, history, and mailbox webhook/poll triggers. |
| `google_gmail_triage` | Metadata pack plus label get, watch lifecycle, attachment retrieval, label create/update, batch message label mutation, and reversible message/thread trash workflows. |
| `google_gmail_send` | Metadata pack plus send and non-destructive draft list/get/create/update/send. |
| `google_gmail_destructive` | Metadata pack plus explicit draft, label, message, and thread delete or trash operations. |

## Drive

Package: `jido_connect_google_drive`

Provider ID: `google_drive`

Auth profiles: `user`, `service_account`,
`domain_delegated_service_account`

### Actions

| ID | Risk | Data | Scope | Required Inputs | Output |
| --- | --- | --- | --- | --- | --- |
| `google.drive.files.list` | read | `workspace_metadata` | `drive.metadata.readonly` | none | `files`, `next_page_token` |
| `google.drive.file.get` | read | `workspace_metadata` | `drive.metadata.readonly` | `file_id` | `file` |
| `google.drive.file.create` | write | `workspace_metadata` | `drive.file` | `name` | `file` |
| `google.drive.folder.create` | write | `workspace_metadata` | `drive.file` | `name` | `folder` |
| `google.drive.file.copy` | write | `workspace_metadata` | `drive.file` | `file_id` | `file` |
| `google.drive.file.update` | write | `workspace_metadata` | `drive.file` | `file_id` | `file` |
| `google.drive.file.export` | read | `workspace_content` | `drive.readonly` | `file_id`, `mime_type` | `file_content` |
| `google.drive.file.download` | read | `workspace_content` | `drive.readonly` | `file_id` | `file_content` |
| `google.drive.file.delete` | destructive | `workspace_metadata` | `drive.file` | `file_id` | `result` |
| `google.drive.permissions.list` | read | `personal_data` | `drive.metadata.readonly` | `file_id` | `permissions`, `next_page_token` |
| `google.drive.permission.create` | external_write | `personal_data` | `drive.file` | `file_id`, `type`, `role` | `permission` |
| `google.drive.changes.watch` | write | `workspace_metadata` | `drive.metadata.readonly` | `page_token`, `channel_id`, `address` | `channel` |
| `google.drive.file.watch` | write | `workspace_metadata` | `drive.metadata.readonly` | `file_id`, `channel_id`, `address` | `channel` |
| `google.drive.channel.stop` | write | `workspace_metadata` | `drive.metadata.readonly` | `channel_id`, `resource_id` | `result` |

### Triggers

| ID | Kind | Checkpoint | Dedupe | Scope | Signal |
| --- | --- | --- | --- | --- | --- |
| `google.drive.file.changed` | poll | `page_token` | `change_id`, `file_id` | `drive.metadata.readonly` | `change_id`, `file_id`, removed, time, drive ID, change type, file |
| `google.drive.file.changed.push` | webhook | none | `channel_id`, `resource_id`, `message_number` | `drive.metadata.readonly` | channel id, resource id, resource URI, state, changed parts, optional file id, delivery metadata |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_drive_readonly` | File list/get, export/download, permission list, file-changed polling, and file-changed webhook metadata. |
| `google_drive_file_writer` | Read-only pack plus file create, folder create, file copy, and file update. |
| `google_drive_watch` | Read-only pack plus Drive changes/file watch creation and channel stop lifecycle actions. |

## Calendar

Package: `jido_connect_google_calendar`

Provider ID: `google_calendar`

Auth profiles: `user`

### Actions

| ID | Risk | Data | Scope | Required Inputs | Output |
| --- | --- | --- | --- | --- | --- |
| `google.calendar.calendar.list` | read | `personal_data` | `calendar.calendarlist.readonly` | none | `calendars`, `next_page_token`, `next_sync_token` |
| `google.calendar.event.list` | read | `personal_data` | `calendar.events.readonly` | `calendar_id` | `events`, `next_page_token`, `next_sync_token` |
| `google.calendar.event.get` | read | `personal_data` | `calendar.events.readonly` | `calendar_id`, `event_id` | `event` |
| `google.calendar.event.create` | write | `personal_data` | `calendar.events` | `calendar_id`, `start`, `end` | `event` |
| `google.calendar.event.update` | write | `personal_data` | `calendar.events` | `calendar_id`, `event_id` | `event` |
| `google.calendar.event.delete` | destructive | `personal_data` | `calendar.events` | `calendar_id`, `event_id` | `result` |
| `google.calendar.freebusy.query` | read | `personal_data` | `calendar.events.freebusy` | `calendar_ids`, `time_min`, `time_max` | `free_busy` |
| `google.calendar.availability.find` | read | `personal_data` | `calendar.events.freebusy` | `calendar_ids`, `time_min`, `time_max` | `windows`, `free_busy` |

### Trigger

| ID | Kind | Checkpoint | Dedupe | Scope | Signal |
| --- | --- | --- | --- | --- | --- |
| `google.calendar.event.changed` | poll | `sync_token` | `event_id`, `updated` | `calendar.events.readonly` | `event_id`, calendar ID, status, change type, summary, start, end, updated, event |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_calendar_reader` | Calendar/event reads, free/busy, availability search, and event-changed polling. |
| `google_calendar_scheduler` | Reader pack plus event create, update, and delete. |

## Contacts

Package: `jido_connect_google_contacts`

Provider ID: `google_contacts`

Auth profiles: `user`

### Actions

| ID | Risk | Data | Scope | Required Inputs | Output |
| --- | --- | --- | --- | --- | --- |
| `google.contacts.person.list` | read | `personal_data` | `contacts.readonly` | none | `people`, `next_page_token`, `next_sync_token`, `total_items` |
| `google.contacts.person.get` | read | `personal_data` | `profile`, `contacts.readonly` | `resource_name` | `person` |
| `google.contacts.person.search` | read | `personal_data` | `contacts.readonly` | `query` | `people` |
| `google.contacts.group.list` | read | `personal_data` | `contacts.readonly` | none | `groups`, `next_page_token`, `next_sync_token` |
| `google.contacts.person.create` | write | `personal_data` | `contacts` | none | `person` |
| `google.contacts.person.update` | write | `personal_data` | `contacts` | `resource_name`, `etag` | `person` |
| `google.contacts.person.delete` | destructive | `personal_data` | `contacts` | `resource_name` | `result` |
| `google.contacts.group.create` | write | `personal_data` | `contacts` | `name` | `group` |
| `google.contacts.group.update` | write | `personal_data` | `contacts` | `resource_name`, `name` | `group` |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_contacts_readonly` | Person list/get/search and contact-group list. |
| `google_contacts_manager` | Read-only pack plus person create/update/delete and group create/update. |

### Triggers

No trigger specs are currently exposed.

## Existing-Package Expansion Epic

The provider gap audit generated a new expansion epic for the current Google
packages:

| Ticket | Scope |
| --- | --- |
| `jido_con-5zt` | Existing Google package expansion. |
| `jido_con-5zt.1` | Sheets spreadsheet create and value batch actions. |
| `jido_con-5zt.2` | Sheets data-filter and developer metadata actions. |
| `jido_con-5zt.3` | Gmail watch/history and attachment actions. |
| `jido_con-5zt.4` | Gmail draft, message, thread, and label lifecycle actions. |
| `jido_con-5zt.5` | Drive watch/channel lifecycle and webhook trigger metadata. |
| `jido_con-5zt.6` | Drive revision and permission lifecycle actions. |
| `jido_con-5zt.7` | Drive comments, replies, and shared-drive actions. |
| `jido_con-5zt.8` | Calendar watch/channel lifecycle actions. |
| `jido_con-5zt.9` | Calendar calendar, ACL, and event utility actions. |
| `jido_con-5zt.10` | Contacts batch, directory, and other-contact actions. |
| `jido_con-5zt.11` | Contacts group membership and sync trigger. |
| `jido_con-5zt.12` | Expansion catalog packs, docs, and action availability tests. |

## Planned New Package Epics

The current audit gates the next Google package epics so each new connector can
reuse the same conventions and hardening expectations:

| Ticket | Package |
| --- | --- |
| `jido_con-9sn` | Google Meet |
| `jido_con-b9n` | Google Analytics |
| `jido_con-nqr` | Google Search Console |
| `jido_con-fle` | Google Docs |
| `jido_con-qc1` | Google Slides |
| `jido_con-uoi` | Google Forms |
| `jido_con-54m` | Google Tasks |
