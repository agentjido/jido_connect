# Live smoke tests

Use a dedicated test account with synthetic data. Tag live tests with
`:live_smoke`. In each package that adds one, exclude the tag in
`test/test_helper.exs` and load the shared helper.

```elixir
ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end
```

In the live test module, use `ExUnit.Case, async: false` and
`Jido.Connect.TestSupport.LiveSmoke`. Use `@tag env!([...])` to declare
required variables. The helper skips the test if a variable is empty or
unset. A test that writes to the provider also uses `@tag write!(:provider)`.
The write gate requires the corresponding variable to equal `true`.

Run live tests explicitly from the umbrella root.

```sh
MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke
```

## Recording and replay

Set `JIDO_CONNECT_RECORD=1` to enable recording. In the test, call
`LiveSmoke.record({app, req_options_key}, provider, name)` before the request.
The recorder installs a temporary Req adapter. Keep recording tests serial.
The recorder writes the response status, sanitized path, headers and body into
`test/fixtures/<provider>/recorded`. Each subsequent response gets a numbered
file name; responses of one test that finish at the same time are written one
after the other and numbered in that order. A recording fails if the
destination already exists. To refresh a fixture, record with `:root` set to
a temporary directory. Review the new files before replacing the old ones.
Keep only the files that tests use.

Leave Req body decoding enabled for structured responses. The recorder can
redact fields by key when it receives a decoded body. A test can use
`:transform` to reduce the recorded body or skip a response. Document any
transform that changes the fixture. Load the body in an offline test with
`LiveSmoke.fixture!/2`.

For inbound delivery replay, pass a signed capture and the provider signing
secret to `LiveSmoke.write_capture!/4`. It verifies the original Slack or Jira
signature, sanitizes the capture and signs it with the fixture key. Pass the
sanitized file and a provider that implements `verify_delivery/4` to
`LiveSmoke.replay/2`. The Slack connector supplies this verifier.
Use a fresh destination for each capture. Capture conversion also fails if
the destination already exists.

## Fixture review

Keep credentials in a password manager or a local file outside the
repository. Load them into the shell for the test. Keep raw captures
outside the repository. Use synthetic content wherever possible.

The sanitizer removes sensitive headers and keys, replaces recognized
identifiers, and checks for known values in several encodings, percent escapes
in either case included. Learned names are never replaced inside email
addresses or placeholders, and names longer than 200 bytes are not learned. Opaque or
nested content can still contain private data. Review every request path,
header and body before committing a fixture. Check encoded text, attachments,
provider identifiers and tenant URLs. Remove files that the tests do not load.

Run the fixture checks with the test credentials and settings loaded. A
failure identifies the file and affected fields. A passing check means that
the scanner found no known leaks in the files it inspected.

```sh
mix test apps/jido_connect/test/jido_connect/test_support/live_smoke_fixtures_test.exs
```

Report the test date, command, result and the digest of each reviewed fixture.
Keep credentials, response content and raw assertion output out of reports.

## Variables

Add provider-specific variables when a provider adopts the helper. Use
`JIDO_CONNECT_RECORD=1` only when you intend to write fixtures. The leak check
also checks nonempty variables whose names end in `_TOKEN`, `_SECRET`,
`_PASSWORD` or `_API_KEY`.

| Variable | Purpose |
| --- | --- |
| `GOOGLE_ACCESS_TOKEN` | Google test access token |
| `GOOGLE_REFRESH_TOKEN` | Google test refresh token |
| `GOOGLE_CLIENT_ID` | Google test OAuth client identifier |
| `GOOGLE_CALENDAR_ID` | Google test calendar identifier |
| `GOOGLE_GMAIL_QUERY` | Query for synthetic test messages |
| `GOOGLE_LIVE_DESTRUCTIVE` | Explicitly enables Google live writes |
| `SLACK_BOT_TOKEN` | Slack test bot token |
| `SLACK_SIGNING_SECRET` | Slack test signing secret |
| `JIDO_PUBLIC_URL` | Tunnel URL for test deliveries |
| `SLACK_LIVE_DESTRUCTIVE` | Explicitly enables Slack live writes |
| `JIRA_WEBHOOK_SECRET` | Jira test signing secret |
| `JIRA_SITE` | Jira test site URL |
| `JIRA_EMAIL` | Jira test user email |
| `JIRA_LIVE_DESTRUCTIVE` | Explicitly enables Jira live writes |
| `CONFLUENCE_SITE` | Confluence test site URL |
| `CONFLUENCE_LIVE_DESTRUCTIVE` | Explicitly enables Confluence live writes |
| `TEMPO_OAUTH_REDIRECT_URI` | Tempo test OAuth callback URL |
| `TEMPO_LIVE_DESTRUCTIVE` | Explicitly enables Tempo live writes |

### Google Calendar

| Variable | Kind | Use |
| --- | --- | --- |
| `GOOGLE_CALENDAR_EVENT_ID` | setting | Meeting with a 963-byte description, the test user and `GOOGLE_SEED_ATTENDEES` as attendees, an agenda and a handout attachment, and Meet data |
| `GOOGLE_CALENDAR_AGENDA_FILE_ID` | setting | Google Docs agenda attached to that event |
| `GOOGLE_CALENDAR_HANDOUT_URL` | setting | URL-only attachment of that event, ending in `&jcl=a%20b` |
| `GOOGLE_CALENDAR_CONFERENCE_ID` | setting | Meet conference ID of that event |
| `GOOGLE_MEET_RECORDING_FILE_ID` | setting | Drive file of that recording, also attached to `GOOGLE_CALENDAR_EVENT_ID` |
| `GOOGLE_MEET_NOTES_DOCUMENT_ID` | setting | Gemini notes document of that meeting, attached to `GOOGLE_CALENDAR_EVENT_ID`; in the test tenant Meet writes the transcript as a tab of it, so it is also the transcript's document. Where transcript and notes are separate documents, the Drive export test needs the notes document |
| `GOOGLE_TEST_USER` | setting | Seed input: the test user |
| `GOOGLE_SEED_ATTENDEES` | setting | Seed input: attendees for seeded events |

### Gmail

| Variable | Kind | Use |
| --- | --- | --- |
| `GOOGLE_GMAIL_METADATA_ACCESS_TOKEN` | credential | Access token minted from it |
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

### Google Drive

| Variable | Kind | Use |
| --- | --- | --- |
| `GOOGLE_DRIVE_ONLY_ACCESS_TOKEN` | credential | Access token narrowed to `drive`, minted per run from `GOOGLE_REFRESH_TOKEN` by a refresh with `scope=https://www.googleapis.com/auth/drive`; use it only when the `scope` field of the refresh response is exactly that scope |
| `GOOGLE_DRIVE_SHARED_LINK_URL` | setting | Link to a link-shared file. The file in the test tenant has no resource key, so the live checks send the resource-key header only with a made-up key, for a missing file |
| `GOOGLE_DRIVE_SHORTCUT_ID` | setting | Shortcut to that file |
| `GOOGLE_DOCS_TABBED_DOCUMENT_ID` | setting | Document with nested tabs |
| `GOOGLE_DRIVE_STARRED_FILE_ID` | setting | Starred file; its folder also holds exactly one unstarred file named `jcl-live unstarred.txt` |
| `GOOGLE_DRIVE_FOLDER_ID` | setting | Folder with known direct children |
| `GOOGLE_DRIVE_WATCH_FOLDER_ID` | setting | Folder for externally added files |
| `GOOGLE_DRIVE_UPLOAD_FOLDER_ID` | setting | Upload folder created by the app |
| `GOOGLE_DRIVE_EDIT_FILE_ID` | setting | File that a write test may edit |
