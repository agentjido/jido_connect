# Jido Connect Slack

`jido_connect_slack` is the Slack provider package for `jido_connect`.

It includes:

- `Jido.Connect.Slack`, a Spark-authored provider that compiles into Jido tools
- generated actions for listing conversations, reading conversation history,
  and posting, updating, and deleting messages
- OAuth v2 helpers in `Jido.Connect.Slack.OAuth`
- Slack Web API helpers in `Jido.Connect.Slack.Client`
- signed request verification and Events API helpers in `Jido.Connect.Slack.Webhook`
- verification of signed interactivity requests in `Jido.Connect.Slack.Interactivity`

The Spark DSL declaration lives in `lib/jido_connect/slack/integration.ex`.
Provider handlers live under `lib/jido_connect/slack/handlers/`.

## Installation

```elixir
def deps do
  [
    {:jido_connect_slack, "~> 0.8"}
  ]
end
```

## OAuth

Slack apps use OAuth v2. Hosts own state, installation storage, and credential
storage. This package builds authorize URLs and exchanges callback codes:

For local development, generate a Slack app creation URL from the current ngrok
tunnel:

```sh
mix jido.connect.slack.app.manifest_url
```

Pass `--events` and `--interactivity` only after the host exposes routes that
can answer Slack verification requests.

```elixir
url =
  Jido.Connect.Slack.OAuth.authorize_url(
    client_id: "123.456",
    redirect_uri: "https://example.ngrok-free.app/integrations/slack/oauth/callback",
    state: "csrf-state",
    scopes: ["channels:read", "chat:write"]
  )

{:ok, token} =
  Jido.Connect.Slack.OAuth.exchange_code("code",
    client_id: "123.456",
    client_secret: "secret",
    redirect_uri: "https://example.ngrok-free.app/integrations/slack/oauth/callback"
  )
```

Hosts turn the token response into a durable `Jido.Connect.Connection` and a
short-lived `Jido.Connect.CredentialLease` before running generated actions.

## Conversation history

`slack.conversation.history` reads one page of a conversation through Slack
`conversations.history`, newest message first, with the bot or the user
profile.

Inputs:

- `channel` and `conversation_type` are required. `conversation_type` is one
  of `public_channel`, `private_channel`, `im` and `mpim`. It selects the
  required scope (`channels:history`, `groups:history`, `im:history` or
  `mpim:history`) and is not sent to Slack. The package does not infer the
  type from the channel ID, because Slack gives private channels and group
  DMs IDs that start with `C`. A tool availability check without a
  `conversation_type` offers the action to a connection with any one of these
  scopes; each call still needs the scope of its type.
- `cursor`, `oldest`, `latest` and `inclusive` (default `false`) go to Slack
  unchanged.
- `limit` defaults to 100 and must be from 1 through 100. The bound is a
  package choice; Slack accepts larger pages.

One call sends one request and returns one page: `messages`, `next_cursor`
(an empty string on the last page), `has_more` and, only when Slack sends it,
`is_limited`. Pass `next_cursor` as `cursor` to read the next page. The action
does not retry, does not read further pages on its own and does not change
read state.

Each message is a map with the fields of `Jido.Connect.Slack.Message`:
`channel`, `conversation_type`, `ts`, `thread_ts`, `user`, `bot_id`, `app_id`,
`text`, `blocks`, `attachments`, `files`, `subtype` and `edited` (`user` and
`ts` of the last edit). Timestamps stay Slack's strings, and `text` is the
full text. An empty text stays `""`; a field Slack does not send is `nil`.
Authors are the IDs Slack sends and are never derived. In
`conversations.history`, an uploaded file arrives as a message with `files`,
from a person or from the bot, without the `file_share` subtype. A record
without `ts` or with a wrongly typed field makes the call fail with
`:invalid_response`.

`channel` and `conversation_type` repeat the input. Slack returns no
conversation type, so `conversation_type` is the caller's unchecked
declaration and only selects the scope check. A group DM declared as
`public_channel` passes that check with `channels:history`; if the token also
holds `mpim:history`, which Slack requires, the read succeeds and its messages
say `public_channel`. Do not base visibility, indexing or policies on this
field. The `is_private`, `is_im` and `is_mpim` flags of
`slack.conversation.info` or the host's own record say what a conversation is.

## Rate limits

Slack answers a rate-limited call with HTTP 429 and an `ok: false` body. Every
Slack action returns an `ok: false` response as a
`Jido.Connect.Error.ProviderError` that keeps the `Retry-After` delay in
seconds as `details.retry_after`. An HTTP failure without an `ok: false` body,
such as a 503 with a text body, and a failed upload of file content carry no
`retry_after`. The package does not retry.

## Message deletion

`slack.message.delete` calls Slack `chat.delete` with `channel` and `ts`. It is
marked destructive and always requires confirmation. Slack allows both bot and
user tokens with `chat:write`, but the token determines what can be deleted: a
bot token can delete only messages posted by that bot, while a user token can
delete only messages that user can delete in Slack.

## Webhooks

Use `Jido.Connect.Slack.Webhook.verify_request/4` from a Plug or Phoenix
controller with the raw request body and Slack signing secret. Verification
checks the `v0` HMAC signature and rejects timestamps outside the replay window.

Events API `url_verification` callbacks can be handled with
`Jido.Connect.Slack.Webhook.url_verification_challenge/1`.

## Interactivity

Slack posts button clicks, shortcuts and other interactions to the app's
interactivity request URL as a form body whose `payload` field holds JSON.
`Jido.Connect.Slack.Interactivity.verify_delivery/4` takes the exact raw body,
the request headers, the signing secret and options, and returns a verified
`Jido.Connect.WebhookDelivery`:

```elixir
{:ok, delivery} =
  Jido.Connect.Slack.Interactivity.verify_delivery(raw_body, headers, signing_secret,
    seen_delivery_ids: processed_ids
  )
```

Options:

- `:max_body_bytes` bounds the raw body, by default 262,144 bytes (256 KiB);
  `nil` also selects the default. A larger body fails with reason
  `:body_too_large` before the signature check.
- `:now` sets the current Unix time for the five-minute timestamp window.
- `:seen_delivery_ids` lists delivery IDs the host has already processed.

The signature and timestamp checks are those of
`Jido.Connect.Slack.Webhook.verify_signature/4` and return its auth errors. The
body must hold exactly one `payload` field whose JSON value is an object;
otherwise the error reason is `:missing_payload`, `:duplicate_payload` or
`:invalid_payload`.

Slack sends no delivery ID with interactivity requests. The delivery ID is the
lowercase hex SHA-256 of the verified raw body. A byte-identical redelivery
gets the same ID and is marked `duplicate?: true` when that ID is in
`:seen_delivery_ids`; a body that differs in any byte gets another ID.

`event` is the payload `type`, and `metadata` carries `team_id` and
`api_app_id`. `payload` is the decoded object without the temporary
capabilities `token`, `bot_access_token`, `response_url`, `response_urls` and
`trigger_id`. A `view_submission` can also carry `response_urls` inside `view`,
and an interaction from a workflow step carries
`interactivity.interactivity_pointer`; both are dropped as well. `interactor`
and `function_data` stay. The raw body is not kept. No payload type is
normalized yet, so `normalized_signal` is `nil`.
Verification makes no HTTP request and does not acknowledge the request; the
host answers Slack.
