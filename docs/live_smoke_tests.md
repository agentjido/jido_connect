# Live Smoke Tests

Live smoke tests call a provider's real API with a dedicated test account. They
check that a connector works against the provider and supply the recorded
responses that offline tests use as `Req.Test` fixtures. A response shape
written from memory or from documentation alone is not a recording.

The convention lives in `Jido.Connect.TestSupport.LiveSmoke`
(`apps/jido_connect/test/support/live_smoke.ex`). Live runs happen only on a
developer machine with credentials in the shell. They never run in CI.

## Running

Every live test carries the `:live_smoke` tag. The test helpers of the packages
that adopt the convention start ExUnit with `exclude: [:live_smoke]`, so a plain
`mix test` never calls a provider. Run the live tests of one package with:

```sh
set -a; source ~/.config/jido_connect/live/google.env; set +a
cd apps/jido_connect_gmail
mix test --only live_smoke
```

The env files hold plain `NAME=value` lines, so `set -a` exports them to
`mix`. Google access tokens expire after an hour and are not stored: mint
`GOOGLE_ACCESS_TOKEN` and `GOOGLE_GMAIL_METADATA_ACCESS_TOKEN` from the refresh
tokens before each run. The Docs and Drive checks of a Drive-only grant also
need `GOOGLE_DRIVE_ONLY_ACCESS_TOKEN`. A refresh of `GOOGLE_REFRESH_TOKEN`
that adds `scope=https://www.googleapis.com/auth/drive` to the token request
returns a token narrowed to that scope; Google reports the granted scopes in
the `scope` field of the response, and a run uses the token only when that
field is exactly the Drive scope. These checks, in
`apps/jido_connect_google_docs/test/jido_connect/google/docs/live_smoke_test.exs`
and `apps/jido_connect_google_drive/test/jido_connect/google/drive/live_tabbed_export_test.exs`,
ask Google's `tokeninfo` endpoint again before they read, so a run with a
broader token fails.

The Slack, Jira, Confluence and Tempo packages declare `plug` as a test-only
dependency, which conflicts with a transitive dependency when Mix runs inside
the app directory. Run them from the umbrella root instead:

```sh
MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke
```

The packages that load the harness are `jido_connect_gmail`,
`jido_connect_google_calendar`, `jido_connect_google_meet`,
`jido_connect_google_drive`, `jido_connect_google_docs`, `jido_connect_slack`,
`jido_connect_jira`, `jido_connect_confluence` and `jido_connect_tempo`. Each
has a `live_smoke_test.exs` with at least one read-only test. New packages
adopt the same `test_helper.exs` lines when they are created:

```elixir
ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end
```

Gmail keeps its capability checks beside `live_smoke_test.exs` in
`apps/jido_connect_gmail/test/jido_connect/gmail/`, one file per capability
family: `discovery_live_smoke_test.exs` for inbox and archive discovery,
`content_live_smoke_test.exs` for message and thread content and forwards,
`content_client_forwards_live_smoke_test.exs` for forwards that Outlook Web
and Gmail Web built, `attachments_live_smoke_test.exs` for attachment content,
`history_live_smoke_test.exs` for the new-message and change polls and Trash,
`labels_live_smoke_test.exs` for labels and archiving, and
`send_live_smoke_test.exs` for sending mail and drafts. Their shared helpers
are in `test/support/live_gmail.ex`, which the package's `test_helper.exs`
loads.

The four client forwards in `GOOGLE_GMAIL_CLIENT_FORWARD_*` are real mail
with a person's name, signature, addresses and images. Their check reads them
through the content and attachment actions and records nothing, also when the
run sets `JIDO_CONNECT_RECORD=1`, because it never calls `LiveGmail.record/1`,
the only way a live test records. It looks at text only for the marker lines,
the `JCL Quelle` subject and signs of wrong decoding, and its assertions name
the forward and the check instead of printing text. The shapes these forwards
showed that no other recording had are rebuilt with synthetic content in the
messages of `GOOGLE_GMAIL_FORWARD_RELATED_ID` and
`GOOGLE_GMAIL_FORWARD_UNTITLED_ID`, which `content_live_smoke_test.exs`
records as `message_full_forward_related` and `message_full_forward_untitled`
with the attachment bytes of each.

The send check is the one Gmail check that mails another mailbox. With
`GOOGLE_LIVE_DESTRUCTIVE=true` it sends a new mail and a reply in the same
thread to `GOOGLE_GMAIL_RECIPIENT`, so each run puts two mails there, and
those copies stay. Keep such runs few. The draft check addresses its draft to
the same mailbox and sends nothing. Subjects and bodies hold umlauts. Both
tests read back what Gmail stores in `format=raw`, outside the connector and
the recorder, and the subject and body through
`google.gmail.message.content.get`, and delete the sender's copies, the draft
and an inserted message when they exit. Gmail answered 500 to deleting a
message right after sending it, so `LiveGmail.delete_message!/2` and
`LiveGmail.delete_draft!/2` retry transient failures. The recordings
`message_send.json`, `message_send_reply.json`, `draft_create.json` and
`draft_update.json` each hold the answer to one write. The content reads
record as `message_content_sent` and `message_content_draft`, which no offline
test uses and which are not committed.

## Writing a Live Test

```elixir
defmodule Jido.Connect.Slack.LiveSmokeTest do
  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  @tag env!(["SLACK_BOT_TOKEN"])
  test "auth.test accepts the bot token", %{env: env} do
    LiveSmoke.record({:jido_connect_slack, :slack_req_options}, :slack, "auth_test")
    assert {:ok, _identity} = Jido.Connect.Slack.Client.auth_test(env["SLACK_BOT_TOKEN"])
  end

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_PUBLIC_CHANNEL_ID"])
  @tag write!(:slack)
  test "posts and deletes a message", %{env: env} do
    # ...
  end
end
```

`use LiveSmoke` tags the module with `:live_smoke`, imports `env!/1` and
`write!/1`, and adds a setup that puts the variable values into the test
context under `:env`.

`env!/1` takes the variable names a test needs; list them all in one call,
because a second `env!/1` tag on the same test replaces the first list. It
rejects names that this document does not list, so a typo fails at once. When a variable is unset or
empty, the test is skipped and the reason names the variable. ExUnit does not
print skip reasons, so a run that includes `:live_smoke` prints a line such as:

```text
live_smoke skip test/jido_connect/gmail/live_smoke_test.exs:20: set GOOGLE_ACCESS_TOKEN to run this live test
```

`write!/1` marks a test that changes data in the provider account. The test is
skipped unless `<PROVIDER>_LIVE_DESTRUCTIVE=true`, the gate that
`MICROSOFT_LIVE_DESTRUCTIVE` already applies in `jido_connect_microsoft_onedrive`.
If a skipped test runs anyway, for example with `--include skip`, the setup
raises for an unset or empty variable and refuses a write while the gate is
closed. A `setup_all` callback runs before that check, so keep provider calls
out of `setup_all`.

Use `async: false`: recording changes application environment and runs one
recorder per test.

## Variables

Credentials live in a password manager and in local, uncommitted files such as
`~/.config/jido_connect/live/google.env`, sourced into the shell before a run.
They never go into the repository, CI, a fixture or a ticket comment. Values
marked as credentials below are checked by the leak guard of every recording
and capture, and so is every set variable whose name ends in `_TOKEN`,
`_SECRET`, `_PASSWORD` or `_API_KEY`. Variables starting with `SEED_` or marked
as seed input belong to the scripts that create the test data.

### Google Workspace

| Variable | Kind | Meaning |
| --- | --- | --- |
| `GOOGLE_CLIENT_ID` | setting | OAuth client of the test Cloud project |
| `GOOGLE_CLIENT_SECRET` | credential | OAuth client secret |
| `GOOGLE_REFRESH_TOKEN` | credential | Refresh token with the full test scopes |
| `GOOGLE_ACCESS_TOKEN` | credential | Access token minted per run from the refresh token |
| `GOOGLE_GMAIL_METADATA_REFRESH_TOKEN` | credential | Refresh token with `gmail.metadata` only |
| `GOOGLE_GMAIL_METADATA_ACCESS_TOKEN` | credential | Access token minted from it |
| `GOOGLE_DRIVE_ONLY_ACCESS_TOKEN` | credential | Access token narrowed to `drive`, minted per run from `GOOGLE_REFRESH_TOKEN` by a refresh with `scope=https://www.googleapis.com/auth/drive`; use it only when the `scope` field of the refresh response is exactly that scope |
| `GOOGLE_GMAIL_QUERY` | setting | Query matching exactly five prepared messages, two of them archived |
| `GOOGLE_GMAIL_THREAD_ID` | setting | Three-message conversation |
| `GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID` | setting | Message with attachments and nested parts |
| `GOOGLE_GMAIL_FORWARD_INLINE_ID` | setting | Inline forward |
| `GOOGLE_GMAIL_FORWARD_ATTACHED_ID` | setting | Forward as attachment |
| `GOOGLE_GMAIL_FORWARD_OPAQUE_ID` | setting | Forward with an empty and a header-only `message/rfc822` part, both of which Gmail splits into nested parts |
| `GOOGLE_GMAIL_FORWARD_RELATED_ID` | setting | Forward as attachment in the shape Outlook Web builds: outer and enclosed text in `multipart/alternative`, the HTML with two and one inline images in a `multipart/related` inside it, each image with a `Content-ID` in Outlook's form, an rfc822 part whose disposition names no file, an outer subject other than the enclosed one, and a file attachment in the enclosed forward |
| `GOOGLE_GMAIL_FORWARD_UNTITLED_ID` | setting | Forward as attachment in the shape Gmail Web builds, with an empty subject and a `Content-ID` on the rfc822 part and on the file attachment of the enclosed inline forward |
| `GOOGLE_GMAIL_CHARSET_MESSAGE_ID` | setting | Message with ISO-8859-15, US-ASCII and invalid UTF-8 text parts and a base64 `message/rfc822` part |
| `GOOGLE_GMAIL_LARGE_BODY_ID` | setting | Message with a 3 MB windows-1252 `text/plain` part, which Gmail keeps behind an `attachmentId`, and a short HTML alternative |
| `GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID` | setting | Message with attachments without a filename: three binary parts that Gmail keeps behind an `attachmentId`, and six text parts that it returns inline, four of them converted to UTF-8 from ISO-8859-1, Windows-1252 and UTF-16LE |
| `GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_INLINE_ID` | setting | Inline forward that Outlook Web built: text, HTML with inline images and `test.txt`, without a comment line or a quoted original. Real mail, never recorded |
| `GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_ATTACHED_ID` | setting | Forward as attachment that Outlook Web built: the comment line `Kommentar Outlook Anlage` and the Outlook inline forward as a `message/rfc822` part. Real mail, never recorded |
| `GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_INLINE_ID` | setting | Inline forward that Gmail Web built: the comment line `Kommentar Gmail inline`, the forwarded original with a `JCL Quelle` subject and an umlaut line, and `test.txt`. Real mail, never recorded |
| `GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_ATTACHED_ID` | setting | Forward as attachment that Gmail Web built, with an empty subject: the comment line `Kommentar Gmail Anhang` and the Gmail inline forward as a `message/rfc822` part. Real mail, never recorded |
| `GOOGLE_GMAIL_LABEL_ID` | setting | Test label |
| `GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID` | setting | Message that a write test may delete |
| `GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID` | setting | One message of the two-message archive and label thread |
| `GOOGLE_GMAIL_RECIPIENT` | setting | Second mailbox, controlled by the owner of the test data, that receives the mail of the send check |
| `GOOGLE_CALENDAR_ID` | setting | Test calendar with six prepared `jcl-live` events from 2026-11-09 to 2026-11-15, timed in three zones, across midnight, all-day and multi-day, and a weekly series of six Monday occurrences from 2026-11-09 whose second one is moved |
| `GOOGLE_CALENDAR_EVENT_ID` | setting | Meeting with a 963-byte description, the test user and `GOOGLE_SEED_ATTENDEES` as attendees, an agenda and a handout attachment, and Meet data |
| `GOOGLE_CALENDAR_AGENDA_FILE_ID` | setting | Google Docs agenda attached to that event |
| `GOOGLE_CALENDAR_HANDOUT_URL` | setting | URL-only attachment of that event, ending in `&jcl=a%20b` |
| `GOOGLE_CALENDAR_CONFERENCE_ID` | setting | Meet conference ID of that event |
| `GOOGLE_MEET_CONFERENCE_RECORD` | setting | Past meeting with transcript and recording |
| `GOOGLE_MEET_TRANSCRIPT` | setting | Transcript of that meeting |
| `GOOGLE_MEET_RECORDING` | setting | Recording of that meeting |
| `GOOGLE_MEET_RECORDING_FILE_ID` | setting | Drive file of that recording, also attached to `GOOGLE_CALENDAR_EVENT_ID` |
| `GOOGLE_MEET_NOTES_DOCUMENT_ID` | setting | Gemini notes document of that meeting, attached to `GOOGLE_CALENDAR_EVENT_ID`; in the test tenant Meet writes the transcript as a tab of it, so it is also the transcript's document. Where transcript and notes are separate documents, the Drive export test needs the notes document |
| `GOOGLE_MEET_POLL_EVENT_ID` | setting | Calendar event of the fresh meeting for the poll check |
| `GOOGLE_DRIVE_SHARED_LINK_URL` | setting | Link-shared file with a resource key |
| `GOOGLE_DRIVE_SHORTCUT_ID` | setting | Shortcut to that file |
| `GOOGLE_DOCS_TABBED_DOCUMENT_ID` | setting | Document with nested tabs |
| `GOOGLE_DRIVE_STARRED_FILE_ID` | setting | Starred file; its folder also holds exactly one unstarred file named `jcl-live unstarred.txt` |
| `GOOGLE_DRIVE_FOLDER_ID` | setting | Folder with known direct children |
| `GOOGLE_DRIVE_WATCH_FOLDER_ID` | setting | Folder for externally added files |
| `GOOGLE_DRIVE_UPLOAD_FOLDER_ID` | setting | Upload folder created by the app |
| `GOOGLE_DOCS_SCRATCH_DOCUMENT_ID` | setting | Scratch document |
| `GOOGLE_DRIVE_EDIT_FILE_ID` | setting | File that a write test may edit |
| `GOOGLE_DRIVE_DELETE_FILE_ID` | setting | File that a write test may delete |
| `GOOGLE_TEST_USER` | setting | Seed input: the test user |
| `GOOGLE_CLOUD_PROJECT` | setting | Seed input: the test Cloud project |
| `GOOGLE_SEED_ATTENDEES` | setting | Seed input: attendees for seeded events |
| `GOOGLE_LIVE_DESTRUCTIVE` | gate | `true` allows write tests |

### Slack

| Variable | Kind | Meaning |
| --- | --- | --- |
| `SLACK_BOT_TOKEN` | credential | Bot token of the test app |
| `SLACK_SIGNING_SECRET` | credential | Signing secret of the test app |
| `SLACK_USER_TOKEN` | credential | User token of the test user |
| `SLACK_PUBLIC_CHANNEL_ID` | setting | Public channel |
| `SLACK_PRIVATE_CHANNEL_ID` | setting | Private channel |
| `SLACK_DM_CHANNEL_ID` | setting | Direct message |
| `SLACK_MPIM_CHANNEL_ID` | setting | Group direct message |
| `SLACK_NO_ACCESS_CHANNEL_ID` | setting | Channel the bot is not in |
| `SLACK_THREAD_TS` | setting | Thread with replies over more than one page |
| `SLACK_PRIVATE_THREAD_TS` | setting | Thread with seven bot replies in `SLACK_PRIVATE_CHANNEL_ID` |
| `SLACK_DM_THREAD_TS` | setting | Thread with seven bot replies in `SLACK_DM_CHANNEL_ID` |
| `SLACK_MPIM_THREAD_TS` | setting | Thread with seven bot replies in `SLACK_MPIM_CHANNEL_ID` |
| `SLACK_SECOND_USER_ID` | setting | Second human user |
| `SLACK_CAPTURE_DIR` | setting | Capture directory of the demo host |
| `SLACK_APP_ID` | setting | ID of the test app |
| `SLACK_LIVE_DESTRUCTIVE` | gate | `true` allows write tests |

### Jira

| Variable | Kind | Meaning |
| --- | --- | --- |
| `JIRA_SITE` | setting | Site URL, `https://<site>.atlassian.net` |
| `JIRA_EMAIL` | setting | Test user for API token auth |
| `JIRA_API_TOKEN` | credential | API token of the test user |
| `JIRA_PROJECT_KEY` | setting | Test project |
| `JIRA_ISSUE_KEY` | setting | Test issue |
| `JIRA_ISSUE_ID` | setting | Numeric ID of the test issue |
| `JIRA_WEBHOOK_SECRET` | credential | Secret of the registered webhook |
| `JIRA_CAPTURE_DIR` | setting | Capture directory of the demo host |
| `SEED_ADMIN_EMAIL` | setting | Seed input: site administrator |
| `SEED_ADMIN_API_TOKEN` | credential | Seed input: API token of the site administrator |
| `JIRA_LIVE_DESTRUCTIVE` | gate | `true` allows write tests |

### Tempo

| Variable | Kind | Meaning |
| --- | --- | --- |
| `TEMPO_API_TOKEN` | credential | Tempo API token of the test user |
| `TEMPO_OAUTH_CLIENT_ID` | setting | Tempo OAuth application |
| `TEMPO_OAUTH_CLIENT_SECRET` | credential | Tempo OAuth client secret |
| `TEMPO_OAUTH_REDIRECT_URI` | setting | Redirect URI on the demo host |
| `TEMPO_OAUTH_ACCESS_TOKEN` | credential | OAuth access token |
| `TEMPO_OAUTH_REFRESH_TOKEN` | credential | OAuth refresh token; each refresh replaces it |
| `TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT` | setting | Expiry of the stored access token |
| `TEMPO_OAUTH_CODE` | credential | Authorization code of one browser authorization |
| `TEMPO_OAUTH_TOKEN_FILE` | setting | Absolute path of a new or empty file outside the repository that receives the token pair of the exchange test |
| `SEED_TEMPO_API_TOKEN` | credential | Seed input: Tempo API token with admin rights |
| `TEMPO_API_ORIGIN` | setting | Tempo API origin |
| `TEMPO_ACCOUNT_ID` | setting | Tempo account linked to the test project |
| `TEMPO_JIRA_ISSUE_ID` | setting | Jira issue for worklogs |
| `TEMPO_JIRA_PROJECT_ID` | setting | Jira project for worklogs |
| `TEMPO_WORK_ATTRIBUTES` | setting | `required` or `optional`: the mode in which the test work attributes exist for this run; unset when they do not exist |
| `TEMPO_LIVE_DESTRUCTIVE` | gate | `true` allows tests that create worklogs |

The Tempo exchange test runs only when `TEMPO_OAUTH_CODE` is set, taken from
the `code` parameter of the redirect after one browser authorization. One run
consumes the code and rotates the pair: it exchanges the code for a new pair,
refreshes that pair once and writes each pair at once to
`TEMPO_OAUTH_TOKEN_FILE`, with mode 0600, as `TEMPO_OAUTH_ACCESS_TOKEN`,
`TEMPO_OAUTH_REFRESH_TOKEN` and `TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT` lines.
Put that file in a directory only you can write, such as
`~/.config/jido_connect/live`, and name it with an absolute path; the test
fails before the exchange when the path is relative or inside the repository.
The file then holds the only valid refresh token of that authorization; copy
its lines to `atlassian.env` and the password manager. The test does not use
the stored `TEMPO_OAUTH_REFRESH_TOKEN`. With recording on, it writes the two
token responses to `oauth_exchange.json` and `oauth_refresh.json`, with the
token fields redacted, and deletes a file that still holds a token or the
code.

The Tempo own worklog checks are the five tests that record `worklogs_own`,
`worklogs_own_small_page`, `worklogs_own_day`, `worklogs_own_empty` and
`worklogs_own_jira`. They rely only on the test user's seeded worklogs.
Each read except the empty July range is compared with a direct Tempo read,
so further own worklogs from August to October do not break them; the July
read must return no worklogs. Three recordings also hold worklogs that the
test user created on JCL-2 on 2026-11-02, outside the seeded data:
`worklogs_own.2.json` and `worklogs_own_day.json` hold 79166, booked at
00:30 Europe/Berlin on 2026-10-31 with a description of 778 bytes, and
`worklogs_own_jira.json` holds 79167 and 79168, created through Jira's
worklog API without a comment and with an empty one. Re-recording these
files needs those worklogs, since the offline tests pin their IDs and
shapes. An empty answer names the account only in links, so the sanitizer
cannot learn the account ID from it: the empty range is recorded after a
seeded day, and the October 31 test stops in recording mode when that day
has no worklog.

The Tempo worklog create is the one Tempo check that creates data. With
`TEMPO_LIVE_DESTRUCTIVE=true` it creates one worklog of the test user on
`TEMPO_JIRA_ISSUE_ID` on 2026-10-29, in the open October period, reads it
back and books the same input into the approved August period, which Tempo
rejects with a 403. Each run leaves one worklog on 2026-10-29; the package
cannot delete it, so it stays until the test data is cleaned up, and a
re-recording of `worklogs_own` holds it. The test records the create, the
read-back and the rejection in one session, `worklog_create.json` to `.3`,
so the sanitizer learns the account ID from the created worklog's author
before it writes the read-back path. 79177 is the worklog of that
recording. A second write-gated test posts a start time of `25:00:00` into
the approved period for Tempo's 400, `worklog_create_invalid_time.json`;
it cannot create a worklog. If Tempo accepted a booking into the approved
period, either test stops at once and names the new ID.

The Tempo period checks rely only on the seeded approvals of the test user:
August 2026 `APPROVED`, September `IN_REVIEW` and October `OPEN`. Further
worklogs in October do not change them. Each status and its time are
compared with a direct approval read of the same period by the same user.
`period_bookability.json` holds the periods of August 15 to October 15,
2026, and `.2` to `.4` the three approvals; the sanitizer numbers the
reviewer of August first, so the test user is `account-2` there.
`timesheet_approval.json` holds the October approval and `.2` Tempo's 400
for a range across two periods. That 400 names no account in its body, so
it is recorded after the October approval, from whose `user` the sanitizer
learns the account ID before it writes the request path.

The Tempo booking lookup checks are in `booking_lookup_live_smoke_test.exs`.
The account check relies on the seeded accounts alone: JCL-PROJECT
(`TEMPO_ACCOUNT_ID`, the default link), JCL-SECONDARY and the closed
JCL-CLOSED, linked to `TEMPO_JIRA_PROJECT_ID`, and the global JCL-GLOBAL.
The work attribute checks need the five test attributes `_JclPhase_`,
`_JclBillable_`, `_JclHours_`, `_JclAccount_` and `_JclNote_`, which exist
on the shared site only around a run, since every user's time-entry form
shows them.
`~/.config/jido_connect/live/seed/atlassian/tempo_attributes.py up` creates
them, required unless `--optional`, with the free-text `_JclNote_` optional
in both modes, and gives the seeded worklog of October 1, 2026 a value for
each; `down` deletes them and their values.
Those checks run only with `TEMPO_WORK_ATTRIBUTES` set to the mode of the
run, `required` or `optional`, and are skipped without it. The attribute
check compares every test attribute's required flag with that mode and
names its recording after it, `work_attributes_required` or
`work_attributes_optional`. The value check records `work_attribute_values`
in the optional mode only, so a required run never overwrites it. Tempo
assigns new stored values each time `up` creates `_JclPhase_`, and the
offline tests match the stored value in `work_attribute_values` against
`work_attributes_optional`: record those two in the same optional run.
`work_attributes_required` needs a required run of its own.

While the test attributes exist, run only the booking lookup checks, and
run `down` at once after them, also when a check fails or the run is
interrupted. In a required run Tempo lists four of them as required, for
the whole site. The worklog create check sends no attribute values; how
Tempo answers it inside a required window was not tried, so do not run it
there. Run the rest of the Tempo suite after `down`.

The site is shared with real users, and Tempo returns their data in the
same responses: every work attribute of the site and every global account
with each project's links. The recordings leave it out with the
`:transform` option that `LiveTempo.site_data/2` in
`apps/jido_connect_tempo/test/support/live_tempo.ex` builds: other
attributes keep Tempo's structure, with a neutral key `_Other1_` and
onward, name, link, stored values and labels, and their type and required
flag; links of other accounts are left out with `metadata.count` adjusted,
reads of those accounts are not recorded, and worklog values of other
attributes are left out. The live assertions check only the test data and
pass whatever else the site holds.

Of the current recordings, `work_attributes_required.json`,
`work_attributes_optional.json` and `accounts_for_project.json` were
changed this way. They carry `"transformed": true`, added by hand after the
recording; a re-recording writes it itself. The account details
`accounts_for_project.2.json` to `.5.json` are those of test accounts,
which the transform keeps as sent. `work_attribute_values.json` carries no
marker: its recorded `content-length` matches its body once the
sanitizer's replacements of the account ID and the site host are counted
back, so the transform removed no value there.

### Confluence

| Variable | Kind | Meaning |
| --- | --- | --- |
| `CONFLUENCE_SITE` | setting | Site URL, `https://<site>.atlassian.net` |
| `CONFLUENCE_EMAIL` | setting | Test user for API token auth |
| `CONFLUENCE_API_TOKEN` | credential | API token of the test user |
| `CONFLUENCE_PAGE_ID` | setting | Plain page |
| `CONFLUENCE_RICH_PAGE_ID` | setting | Page with images, a macro and an inline comment |
| `CONFLUENCE_RESTRICTED_PAGE_ID` | setting | Page the test user cannot read |
| `CONFLUENCE_LIVE_DESTRUCTIVE` | gate | `true` allows write tests |

A build ticket that needs another variable adds it here and to the variable
list in `LiveSmoke`; a test in `jido_connect` checks that both lists agree.

## Recording

With `JIDO_CONNECT_RECORD=1`, `LiveSmoke.record/4` records the responses of
the current test:

```elixir
LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, "profile")
```

The first argument names the package's existing Req test options. The recorder
joins them as the Req adapter until the test exits; it runs the normal Finch
adapter and appends a response step. Each final response, after retries and
redirects, is sanitized and written to
`test/fixtures/<provider>/recorded/<name>.json` in the package. A second
response in the same test goes to `<name>.2.json`, a third to `<name>.3.json`.
A new recording overwrites files of the same name; delete numbered files that
a shorter run no longer writes. Without `JIDO_CONNECT_RECORD=1` the call does
nothing, so live tests keep the call in place. Recording refuses to start while
the Req options contain `:plug`, because a plug replaces the network.

A test account on a site that real users share returns their data next to the
test data, and the sanitizer does not know which is which. The `:transform`
option of `record/4` takes a function of the decoded request path and the
decoded response body that returns the body to record, or `:skip` to write no
fixture for that response:

```elixir
LiveSmoke.record({:jido_connect_tempo, :tempo_req_options}, :tempo, "accounts",
  transform: fn
    "/4/accounts/" <> id, body -> if id in test_ids, do: body, else: :skip
    _path, body -> body
  end
)
```

The transform runs before the sanitizer, so the leak guard checks its result.
It changes only the fixture; the caller still gets the response as the provider
sent it. A skipped response takes no number. Use it only to leave out or
neutralize data that must not be committed, and say in the test what it
changes, since the fixture then differs from the provider's answer.

A fixture file holds the recording date, the request method and the decoded
path without query, the status, the sanitized response headers and the
sanitized body. When the transform returned a body other than the provider's,
the file also holds `"transformed": true`; its headers, such as
`content-length`, still describe the provider's response. A body that is not
UTF-8, such as a file download, is stored as `"body": null` with `body_bytes`
and `body_sha256`:

```json
{
  "body": {"id": "user-1", "email": "person-1@example.com"},
  "headers": {"content-type": ["application/json"]},
  "recorded_at": "2026-10-30",
  "request": {"method": "GET", "path": "/v1/profile"},
  "status": 200
}
```

Offline tests load the body with `LiveSmoke.fixture!/2`, which returns it
unchanged:

```elixir
Req.Test.stub(MyStub, &Req.Test.json(&1, LiveSmoke.fixture!(:gmail, "profile")))
```

Default test runs do not play recordings back on their own; each build ticket
wires its fixtures into its offline tests.

## Sanitizing

Recordings and captures pass through the same sanitizer, also available as
`LiveSmoke.sanitize/2`, `LiveSmoke.sanitize_headers/2` and
`LiveSmoke.sanitize_capture/2`:

- Headers whose names contain `auth`, `cookie`, `token`, `secret` or
  `signature`, the forwarding headers, and every header that
  `Jido.Connect.Sanitizer.sensitive_key?/1` reports are dropped.
- Values under the sensitive keys of `Jido.Connect.Sanitizer` become
  `"[redacted]"`, in JSON and in form bodies. `fields` is kept by default
  because it is the issue payload of Jira; pass `keep_keys:` to change that.
- Email addresses in values and in map keys become `person-<n>@example.com`.
- Hosts that name a customer site or a developer's tunnel become example
  hosts wherever they appear. A host under `atlassian.net` or one of ngrok's
  domains keeps that domain: `example.atlassian.net`,
  `example-2.atlassian.net`, `example.ngrok-free.dev`. The hosts of
  `JIRA_SITE`, `CONFLUENCE_SITE`, `TEMPO_OAUTH_REDIRECT_URI` and
  `JIDO_PUBLIC_URL`, and the `Host` header of a capture, become
  `host-<n>.example.com` when they are not under such a domain.
- Atlassian account IDs under `accountId`, `authorAccountId`,
  `leadAccountId`, `authorId`, `ownerId` and `lastOwnerId` become
  `account-<n>` wherever they appear, also percent-encoded in links.
- The Google project number, the numeric prefix of `GOOGLE_CLIENT_ID`, becomes
  `000000000000` wherever it appears as a whole number, as in the `Received`
  headers of Gmail messages.
- Display names become `Person <n>`. They are taken from keys such as
  `displayName`, `real_name`, `publicName` and `username`, and from address
  lists such as `Ada Lovelace <ada@example.org>, bob@example.org`. Once known,
  a name is replaced as a whole word, ignoring case, wherever it appears. Pass
  `name_keys:` for more keys, such as Slack's `name`.
- Values under the keys given as `fields:` become `<field>-<n>`, for message
  text or other content a fixture does not need.
- Placeholders are stable within one recording or capture: the same input gets
  the same placeholder.
- If the value of any credential variable listed above, eight bytes or longer,
  still appears in the output, raw or JSON-, percent- or Base64-encoded, the
  sanitizer raises `LiveSmoke.LeakError`. The same holds for the hosts above,
  for the Google project number, also inside a longer number, for email
  addresses in listed settings and in variables ending in `_EMAIL`, and for
  every tenant host and account ID the sanitizer replaced elsewhere.
  The message names the variable or the kind of value, not the value, and
  nothing is written.

The sanitizer does not look inside encoded content. Base64 message bodies,
such as Gmail's `payload.body.data` and `raw`, keep whatever they contain; list
such keys in `fields:` or check them by hand. The leak guard finds a guarded
value there only when the encoding of the value itself appears. Free text
keeps names that never appear under a name key or in an address list, and
names shorter than three bytes stay as they are. Content such as issue
summaries, comments and page bodies stays unless listed in `fields:`. Review
every recording and capture before committing it.

## Capturing Inbound Deliveries

The demo host in `dev/demo` has a capture mode for provider deliveries. When
`SLACK_CAPTURE_DIR` is set, the existing `/integrations/slack/events` and
`/integrations/slack/interactivity` routes write the raw body and headers of
every request into that directory before they verify it. When
`JIRA_CAPTURE_DIR` is set, `/integrations/jira/webhook` captures Jira webhook
deliveries; without it, that route answers 404.

```sh
set -a; source ~/.config/jido_connect/live/slack.env; set +a
(cd dev/demo && mix phx.server)

# second shell, repo root
mix jido.connect.ngrok --port 4000
```

`mix jido.connect.ngrok` prints the public base URL. Point the Slack event and
interactivity request URLs, and the Jira webhook URL, at that base URL plus the
route paths above.

A capture file is named `<provider>-<route>-<unix time>-<n>.json` and holds the
provider, method, path, capture time in Unix seconds, all request headers and
the raw body. Raw captures contain signatures and message content. Keep the
capture directories outside the repository.

`LiveSmoke.write_capture!/4` sanitizes a capture and writes it to
`test/fixtures/<provider>/captured/<name>.json`. Sanitizing changes the body,
so the original signature no longer matches. Slack and Jira captures are
therefore signed again with `LiveSmoke.replay_secret/0`, a fixed test key that
is not a credential. Before that, the original signature must verify with the
provider's signing secret, passed as `:secret`, so an edited capture or an
unsigned request to the public tunnel never becomes a fixture:

```elixir
LiveSmoke.write_capture!(raw_path, :slack, "message_changed",
  secret: env["SLACK_SIGNING_SECRET"],
  fields: ["text"]
)
```

`LiveSmoke.replay/2` passes a capture through a package's
`verify_delivery/4`, with the capture time as `now`:

```elixir
LiveSmoke.replay(path, webhook: Jido.Connect.Slack.Webhook)
LiveSmoke.replay(raw_path, webhook: Jido.Connect.Slack.Webhook, secret: env["SLACK_SIGNING_SECRET"])
LiveSmoke.replay(click_path, webhook: Jido.Connect.Slack.Interactivity, api_app_id: env["SLACK_APP_ID"])
```

A sanitized capture verifies with the default replay secret; a raw capture
needs the provider's signing secret. Any change to the body after signing fails
verification. Other options go on to `verify_delivery/4`. `replay/2` suits
deliveries that the package's `verify_delivery/4` accepts: Slack Events API
payloads (`webhook: Jido.Connect.Slack.Webhook`), Slack interactivity form
bodies such as button clicks (`webhook: Jido.Connect.Slack.Interactivity`) and
Jira administrator webhook deliveries (`webhook: Jido.Connect.Jira.Webhook`).

## Evidence

A live run counts as evidence when its report names the date, the test, the
result, the provider object IDs and counts it observed, and SHA-256 digests of
the recorded or captured files it relies on:

```sh
shasum -a 256 apps/jido_connect_gmail/test/fixtures/gmail/recorded/profile.json
```

A report never contains credentials, message text, document content or other
account content. IDs of test objects are fine; they also appear in this
document's variables. ExUnit prints the arguments of a failing call, which in a
live test can include a token, so do not paste raw failure output into a
report.
