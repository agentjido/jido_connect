# 00 Start here

Use GitHub and Slack to learn Connect's Agent DSL.

1. [Read one pull request](00_01_read_pull_request/README.md). Route a request
   to a generated GitHub read Action.
2. [Watch pull requests](00_02_watch_pull_requests/README.md). Send a Signal
   from a generated GitHub Sensor to an Agent.
3. [Triage a PR with Slack](00_03_triage_with_slack/README.md). Select two
   bindings in one Agent and read a PR and its review channel in one Flow.
4. [Issue credential leases](00_04_credential_leases/README.md). Share one
   stored credential across two grants and test what changes after rotation
   and revocation.
5. [Route a signed GitHub webhook](00_05_github_webhook/README.md). Select a
   webhook Trigger and read a PR when its Signal reaches the Agent.

Run every lesson offline with
`mix test.examples examples/00_start_here --warnings-as-errors`.

The [shared host](support/host.ex) resolves a lease from a credential
reference. Lesson 04 uses its own [host](00_04_credential_leases/lease_host.ex)
to demonstrate rotation and revocation.
