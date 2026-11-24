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
