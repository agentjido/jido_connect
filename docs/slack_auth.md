# Slack Auth And Webhooks

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

## Bot View And User View

A bot token sees the conversations the bot belongs to. A user token of the
person who authorizes the app sees what that person sees, such as a channel
the bot has left or a DM between that person and a colleague. The package
keeps both views apart:

- `Jido.Connect.Slack.OAuth.authorize_url/1` sends `user_scope` beside
  `scope` when the host passes `:user_scope`. For the user's messages these
  are `channels:history`, `groups:history`, `im:history` and
  `mpim:history`. Without `:user_scope` the URL is unchanged.
- `Jido.Connect.Slack.OAuth.exchange_code/2` keeps the bot credential and,
  when Slack returns a user token, adds `authed_user`: `id`, `access_token`,
  `token_type`, `scope` and, with token rotation, `refresh_token`,
  `expires_in` and `expires_at`. A response without a user token has no
  `authed_user`.
- `Jido.Connect.Slack.OAuth.user_credential_lease/3` leases the user token
  for the `:user` profile, which `slack.conversation.history`,
  `slack.thread.replies` and the other actions that declare `:user` accept.
  `bot_credential_lease/3` leases the bot token.
- `Jido.Connect.Slack.AppManifest.build/2` takes `user_scopes:` and
  `user_events:` for `oauth_config.scopes.user` and
  `settings.event_subscriptions.user_events`. With `message.channels`,
  `message.groups`, `message.im` and `message.mpim` as user events, Slack
  delivers the person's messages, edits and deletions to the same request
  URL, and they reach the existing message triggers.

Each message and change signal says whose view it comes from. `view` is
`"bot"` or `"user"`, from `authorizations[].is_bot` of the delivery, and
`viewer` is that authorization's `user_id`. Slack names only one
installation per delivery, even when several can see the event. A share is
a handover to the app when it comes from the bot DM. `view: "bot"` proves
that; with `view: "user"` the host compares `conversation.id` with the bot
DM it knows, since the person sees the bot DM too and Slack does not
document which view it names there. The package README describes the
signals in its section "Bot view and user view".

The tests of `exchange_code/2` use `oauth.v2.access` responses written from
Slack's documentation, in
`apps/jido_connect_slack/test/fixtures/slack/synthetic`. Recording one needs
the app's client secret and a fresh consent in the browser, which the test
workspace does not have; each file names its source and has placeholder
tokens. The user view's reads and deliveries are recorded and captured from
the test workspace.

Hosts store the user token like the bot token, and refresh a rotating token
themselves; the `:user` profile declares no refresh.

## Package Boundary

Hosts own OAuth state, durable installation storage, credential storage, and
event delivery dedupe. The provider package owns:

- `Jido.Connect.Slack.OAuth.authorize_url/1`
- `Jido.Connect.Slack.OAuth.exchange_code/2`
- `Jido.Connect.Slack.OAuth.bot_credential_lease/3`
- `Jido.Connect.Slack.OAuth.user_credential_lease/3`
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
