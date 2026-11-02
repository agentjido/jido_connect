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
tokens before each run.

The Slack, Jira and Confluence packages declare `plug` as a test-only
dependency, which conflicts with a transitive dependency when Mix runs inside
the app directory. Run them from the umbrella root instead:

```sh
MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke
```

The packages that load the harness are `jido_connect_gmail`,
`jido_connect_google_calendar`, `jido_connect_google_meet`,
`jido_connect_google_drive`, `jido_connect_google_docs`, `jido_connect_slack`,
`jido_connect_jira` and `jido_connect_confluence`. Each has a
`live_smoke_test.exs` with one read-only self-test. New packages adopt the same
`test_helper.exs` lines when they are created:

```elixir
ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end
```

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
live_smoke skip test/jido_connect/gmail/live_smoke_test.exs:15: set GOOGLE_ACCESS_TOKEN to run this live test
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
| `GOOGLE_GMAIL_QUERY` | setting | Query matching exactly five prepared messages, two of them archived |
| `GOOGLE_GMAIL_THREAD_ID` | setting | Three-message conversation |
| `GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID` | setting | Message with attachments and nested parts |
| `GOOGLE_GMAIL_FORWARD_INLINE_ID` | setting | Inline forward |
| `GOOGLE_GMAIL_FORWARD_ATTACHED_ID` | setting | Forward as attachment |
| `GOOGLE_GMAIL_FORWARD_OPAQUE_ID` | setting | Forward with an empty and a header-only `message/rfc822` part, both of which Gmail splits into nested parts |
| `GOOGLE_GMAIL_CHARSET_MESSAGE_ID` | setting | Message with ISO-8859-15, US-ASCII and invalid UTF-8 text parts and a base64 `message/rfc822` part |
| `GOOGLE_GMAIL_LARGE_BODY_ID` | setting | Message with a 3 MB windows-1252 `text/plain` part, which Gmail keeps behind an `attachmentId`, and a short HTML alternative |
| `GOOGLE_GMAIL_LABEL_ID` | setting | Test label |
| `GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID` | setting | Message that a write test may delete |
| `GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID` | setting | One message of the two-message archive and label thread |
| `GOOGLE_GMAIL_RECIPIENT` | setting | Second mailbox for sent mail |
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
| `GOOGLE_DRIVE_STARRED_FILE_ID` | setting | Starred file |
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
| `SEED_TEMPO_API_TOKEN` | credential | Seed input: Tempo API token with admin rights |
| `TEMPO_API_ORIGIN` | setting | Tempo API origin |
| `TEMPO_ACCOUNT_ID` | setting | Tempo account linked to the test project |
| `TEMPO_JIRA_ISSUE_ID` | setting | Jira issue for worklogs |
| `TEMPO_JIRA_PROJECT_ID` | setting | Jira project for worklogs |
| `TEMPO_LIVE_DESTRUCTIVE` | gate | `true` allows tests that create worklogs |

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

A fixture file holds the recording date, the request method and the decoded
path without query, the status, the sanitized response headers and the
sanitized body. A body that is not UTF-8, such as a file download, is stored as
`"body": null` with `body_bytes` and `body_sha256`:

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
```

A sanitized capture verifies with the default replay secret; a raw capture
needs the provider's signing secret. Any change to the body after signing fails
verification. `replay/2` suits deliveries that the package's
`verify_delivery/4` accepts, such as Slack Events API payloads and Jira
administrator webhook deliveries (`webhook: Jido.Connect.Jira.Webhook`). Slack
interactivity captures are form bodies; check them with
`Jido.Connect.Slack.Webhook.verify_signature/4` and the capture time as `now`.

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
