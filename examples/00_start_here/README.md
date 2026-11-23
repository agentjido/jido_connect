# 00 Start here

Use one repository and one review channel to learn Connect's Agent DSL.

1. [Read one pull request](00_01_read_pull_request/README.md). Route a request
   to a generated GitHub read Action.
2. [Watch pull requests](00_02_watch_pull_requests/README.md). Send a Signal
   from a generated GitHub Sensor to an Agent.
3. [Triage a PR with Slack](00_03_triage_with_slack/README.md). Select two
   bindings in one Agent and read a PR and its review channel in one Flow.

Run every lesson offline with
`mix test.examples examples/00_start_here --warnings-as-errors`.

The [host](support/host.ex) resolves a current lease from a credential
reference. The [fixture client](support/fixture.ex) handles the same calls as
the real clients. Lesson source uses neither module directly.
