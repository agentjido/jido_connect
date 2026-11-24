# 00_02 Watch pull requests

Drive one poll from the host and route the latest GitHub update to an Agent.

## What you will learn

- Select a trigger in a Connect binding.
- Apply the generated Sensor's tick and emit instructions.
- Keep the checkpoint between ticks and supply current access on each tick.

## Read the code

Read [the Agent and watcher functions](watch_pull_requests.ex), then the
[runner](demo.exs) and [test](watch_pull_requests_test.exs).

## Run it

```sh
mix test.examples examples/00_start_here/00_02_watch_pull_requests --warnings-as-errors
mix run examples/00_start_here/00_02_watch_pull_requests/demo.exs
```

The fixture reports one update for PR 42 and the checkpoint
`2026-01-01T00:00:00Z`. The test drives another tick and verifies that the
checkpoint prevents a repeat event.

Set `GITHUB_TOKEN` and `GITHUB_REPO` to run one live poll on an accessible
repository. Choose a repository with PR activity to see an emitted Signal.

```sh
mix run examples/00_start_here/00_02_watch_pull_requests/demo.exs --live
```

## Important behavior

The host calls the Sensor; the Agent handles the Signal. If a poll returns
zero updates, the runner prints the count and stops its Agent.

## Limits

The live runner processes one search page and delivers its last update. It
keeps the checkpoint in memory for the run. A continuous watcher needs a
scheduler and durable checkpoint storage when it must resume after restart.

Previous: [Read one PR](../00_01_read_pull_request/README.md) |
Next: [Triage a PR with Slack](../00_03_triage_with_slack/README.md)
