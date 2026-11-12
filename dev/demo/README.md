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

Set `SLACK_CAPTURE_DIR` or `JIRA_CAPTURE_DIR` to write the raw body and headers
of Slack or Jira deliveries into that directory for live smoke tests. See
[Live smoke tests](../../docs/live_smoke_tests.md).
