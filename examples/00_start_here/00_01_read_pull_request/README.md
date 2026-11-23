# 00_01 Read one pull request

Ask a live Agent to read one GitHub pull request and save a short summary.

## What you will learn

- Select a generated Action in a `connect do` binding.
- Resolve the Action context from the host and execute the Action with
  `Jido.Exec`.

## Read the code

Read [the Agent](read_pull_request.ex), then the [test](read_pull_request_test.exs).
The [host](../support/host.ex) permits a read only for the selected repository.

## Run it

```sh
mix test.examples examples/00_start_here/00_01_read_pull_request --warnings-as-errors
mix run examples/00_start_here/00_01_read_pull_request/demo.exs
```

Expected state in the fixture:

```elixir
%{pull_request: %{number: 42, state: "open", title: "Update the widgets"}}
```

For a live read, set `GITHUB_TOKEN` through your shell or secret manager.
Set `GITHUB_REPO` to `owner/repo` and `GITHUB_PR_NUMBER` to the PR number.

```sh
mix run examples/00_start_here/00_01_read_pull_request/demo.exs --live
```

Use a token with read access to the PR and its issue metadata in that
repository. See the [GitHub PR API](https://docs.github.com/en/rest/pulls/pulls#get-a-pull-request)
and [issue API](https://docs.github.com/en/rest/issues/issues#get-an-issue).

## Important behavior

The host denies a request for a different repository. A failed Turn keeps the
last committed state. The runner stops its Agent when the call ends.

## Limits

One read request is routed to the Agent. The GitHub action reads both PR and
issue metadata. The runner uses in-memory Agent state.

Next: [Watch pull requests](../00_02_watch_pull_requests/README.md)
