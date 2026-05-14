# Google Surface Audit

This document captures the current Google connector surface from the compiled
integration specs as of May 14, 2026. It is an inventory snapshot, not the
provider API gap analysis. The next Beadwork tasks compare these surfaces to
Google's APIs, create follow-up tickets, and fold the results into the broader
Google hardening plan.

## Beadwork Plan

| Ticket | Purpose |
| --- | --- |
| `jido_con-nmq.1` | Capture current Google action and trigger matrix. |
| `jido_con-nmq.2` | Compare current packages against provider APIs. |
| `jido_con-nmq.3` | Create follow-up tickets for current package gaps. |
| `jido_con-nmq.4` | Write final Google surface audit document. |
| `jido_con-nmq.5` | Reconcile cross-Google hardening dependencies. |

## Current Packages

| Package | Provider ID | Actions | Triggers | Catalog Packs | Auth Profiles |
| --- | --- | ---: | ---: | ---: | --- |
| `jido_connect_google_sheets` | `google_sheets` | 9 | 0 | 2 | `user` |
| `jido_connect_gmail` | `gmail` | 11 | 1 | 3 | `user` |
| `jido_connect_google_drive` | `google_drive` | 11 | 1 | 2 | `user`, `service_account`, `domain_delegated_service_account` |
| `jido_connect_google_calendar` | `google_calendar` | 8 | 1 | 2 | `user` |
| `jido_connect_google_contacts` | `google_contacts` | 9 | 0 | 2 | `user` |

## Cross-Package Notes

- Poll triggers currently exist for Gmail, Drive, and Calendar only.
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
| `google.gmail.messages.list` | read | `message_content` | `gmail.metadata` | none | `messages`, `next_page_token`, `result_size_estimate` |
| `google.gmail.message.get` | read | `message_content` | `gmail.metadata` | `message_id` | `message` |
| `google.gmail.threads.list` | read | `message_content` | `gmail.metadata` | none | `threads`, `next_page_token`, `result_size_estimate` |
| `google.gmail.thread.get` | read | `message_content` | `gmail.metadata` | `thread_id` | `thread` |
| `google.gmail.message.send` | external_write | `message_content` | `gmail.send` | `to`, `subject` | `message` |
| `google.gmail.draft.create` | write | `message_content` | `gmail.compose` | `to`, `subject` | `draft` |
| `google.gmail.draft.send` | external_write | `message_content` | `gmail.compose` | `draft_id` | `message` |
| `google.gmail.label.create` | write | `personal_data` | `gmail.modify` | `name` | `label` |
| `google.gmail.message.labels.apply` | write | `message_content` | `gmail.modify` | `message_id` | `message` |

### Trigger

| ID | Kind | Checkpoint | Dedupe | Scope | Signal |
| --- | --- | --- | --- | --- | --- |
| `google.gmail.message.received` | poll | `history_id` | `message_id` | `gmail.metadata` | `message_id`, `thread_id`, `history_id`, labels, snippet, headers, message |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_gmail_metadata` | Profile, labels, message/thread reads, and the received-message poll trigger. |
| `google_gmail_triage` | Metadata pack plus label creation and message label application. |
| `google_gmail_send` | Metadata pack plus send, draft create, and draft send. |

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

### Trigger

| ID | Kind | Checkpoint | Dedupe | Scope | Signal |
| --- | --- | --- | --- | --- | --- |
| `google.drive.file.changed` | poll | `page_token` | `change_id`, `file_id` | `drive.metadata.readonly` | `change_id`, `file_id`, removed, time, drive ID, change type, file |

### Catalog Packs

| Pack | Surface |
| --- | --- |
| `google_drive_readonly` | File list/get, export/download, permission list, and file-changed polling. |
| `google_drive_file_writer` | Read-only pack plus file create, folder create, file copy, and file update. |

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

