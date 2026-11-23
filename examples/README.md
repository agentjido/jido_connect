# Jido Connect examples

Use these examples to compose a Jido v3 Agent with Connect bindings. The
numbered lessons run with fixture clients by default. Pass `--live` to use the
same Agents, Actions, and Flows with credentials from the host environment.

## Start here

Follow the [three Connect lessons](00_start_here/README.md) in order. Each
lesson has an Agent, a test, and a runner.

```sh
mix deps.get
mix test.examples --warnings-as-errors
```

Run one lesson's tests from the umbrella root:

```sh
mix test.examples examples/00_start_here/00_01_read_pull_request --warnings-as-errors
```

Run the demos in the lesson READMEs. The live lessons make read requests to
the selected GitHub repository or Slack channel. Supply keys through your
shell or secret manager.

## More examples

- [PR triage with an approved Slack post](pr_triage/README.md) uses fixture
  clients to show Connect's prepare and commit flow.
- [Read an MCP resource with a Jido Agent](mcp_ai_agent/README.md) uses a local
  MCP server and a scripted model by default.
