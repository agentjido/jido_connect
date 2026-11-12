# Slack Authentication and Webhooks

`jido_connect_slack` currently ships the provider package slice: generated Jido
actions, OAuth helpers, Web API client helpers, and signed request helpers. The
demo host does not yet persist Slack installations or expose Slack callback
routes.

## App Setup

Generate a Slack app creation URL from the current ngrok tunnel:

```sh
mix jido.connect.slack.app.manifest_url
```

The task writes the manifest to `.secrets/dev-demo/slack-app-manifest.json` and
the creation URL to `.secrets/dev-demo/slack-app-manifest.url`.

The default manifest configures OAuth only. Pass `--events` and
`--interactivity` after the demo host exposes those routes and can answer Slack
verification requests.

The base OAuth scopes are:

- `channels:read`
- `chat:write`

Add the ngrok redirect URL:

```text
https://example.ngrok-free.app/integrations/slack/oauth/callback
```

For future Events API work, configure:

```text
https://example.ngrok-free.app/integrations/slack/events
```

Event subscriptions use Slack's event-specific history scopes:

- `app_mention` requires `app_mentions:read`
- `message.channels` requires `channels:history`
- `message.groups` requires `groups:history`
- `message.im` requires `im:history`
- `message.mpim` requires `mpim:history`

Local env keys:

```sh
SLACK_CLIENT_ID=
SLACK_CLIENT_SECRET=
SLACK_SIGNING_SECRET=
SLACK_BOT_TOKEN=
```

## Package Boundary

Hosts own OAuth state, durable installation storage, credential storage, and
event delivery dedupe. The provider package owns:

- `Jido.Connect.Slack.OAuth.authorize_url/1`
- `Jido.Connect.Slack.OAuth.exchange_code/2`
- `Jido.Connect.Slack.Client.list_channels/2`
- `Jido.Connect.Slack.Client.post_message/2`
- `Jido.Connect.Slack.Client.update_message/2`
- `Jido.Connect.Slack.Client.delete_message/2`
- `Jido.Connect.Slack.Client.upload_file/2`
- `Jido.Connect.Slack.Webhook.verify_request/4`

Generated actions stay thin. Message deletion is exposed as
`slack.message.delete`, a destructive action that always requires confirmation.
Slack `chat.delete` accepts bot and user tokens with `chat:write`; bot tokens
can delete only messages posted by that bot, and user tokens can delete only
messages that user can delete in Slack.

## Signed Requests

Slack signs requests with `X-Slack-Signature` and
`X-Slack-Request-Timestamp`. Verification uses the raw request body and rejects
timestamps outside the replay window.

Use `Jido.Connect.Slack.Webhook.url_verification_challenge/1` for Events API
URL verification callbacks.
