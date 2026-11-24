# Jido Connect Demo

Phoenix host for local integration testing. This app is deliberately outside
the package umbrella; it depends on `apps/jido_connect` and
`apps/jido_connect_github` by local path.

Run it from this directory:

```sh
mix deps.get
mix phx.server
```

If port 4000 is busy:

```sh
JIDO_CONNECT_DEMO_PORT=4001 mix phx.server
```

Useful routes:

- `GET /health`
- `GET /integrations`
- `GET /integrations/github/setup`
- `GET /integrations/github/setup/complete?code=...`
- `GET /integrations/github/oauth/start`
- `GET /integrations/github/oauth/callback`
- `POST /integrations/github/webhook`
- `POST /integrations/slack/events`
- `POST /integrations/slack/interactivity`
- `POST /integrations/jira/webhook` (capture mode only)

Pair it with ngrok from the repo root:

```sh
mix jido.connect.ngrok --port 4000
```

Set `SLACK_CAPTURE_DIR` to a private directory outside the repository to
capture verified Slack events and interactivity requests. `JIRA_CAPTURE_DIR`
with `JIRA_WEBHOOK_SECRET` does the same for Jira administrator webhook
deliveries; the Jira route exists only for capturing. Create the directory
with `mktemp -d` or `mkdir -m 700` before you start the demo.

The capture directory has 20 file slots. Each file holds up to 256 KiB,
including the raw body and the headers needed for replay. When the directory
is full or a capture exceeds the size limit, the demo continues to handle the
request. Move the raw files out of the directory to free slots. Treat them as
private and sanitize them before you commit fixtures.
[Live smoke tests](../../docs/live_smoke_tests.md)
