# 00_03 Triage a PR with Slack

Read a GitHub pull request and its proposed review channel in one Agent Turn.

## What you will learn

- Declare GitHub and Slack bindings in the same `connect do` block.
- Run each generated Action as a Flow step. Connect selects the matching
  binding for each Action.
- Commit one review summary after both reads succeed.

## Read the code

Read [the Agent and Flow](triage_with_slack.ex), then the
[test](triage_with_slack_test.exs). The [host](../support/host.ex) permits the
chosen repository and channel and resolves their credentials separately.

## Run it

```sh
mix test.examples examples/00_start_here/00_03_triage_with_slack --warnings-as-errors
mix run examples/00_start_here/00_03_triage_with_slack/demo.exs
```

Expected state in the fixture:

```elixir
%{review: %{pull_number: 42, channel_id: "C-REVIEW", channel_name: "review", ready?: true}}
```

For a live read, set `GITHUB_TOKEN`, `GITHUB_REPO`, and `GITHUB_PR_NUMBER` as
in [lesson 01](../00_01_read_pull_request/README.md). Also set
`SLACK_BOT_TOKEN` and `SLACK_CHANNEL_ID`. Use a public channel that the bot can
read and grant its token `channels:read`. See the
[Slack conversations.info API](https://docs.slack.dev/reference/methods/conversations.info/).

```sh
mix run examples/00_start_here/00_03_triage_with_slack/demo.exs --live
```

## Important behavior

Putting a GitHub context under the Slack binding fails that Turn and keeps
the last committed state. The runner stops its Agent when the call ends.

## Limits

The Flow reads review metadata only. For an example of posting after approval,
see [PR triage with an approved Slack post](../../pr_triage/README.md).

Previous: [Watch pull requests](../00_02_watch_pull_requests/README.md) |
Next: [Issue credential leases](../00_04_credential_leases/README.md)
