# Jido Connect Slack

`jido_connect_slack` is the Slack provider package for `jido_connect`.

It includes:

- `Jido.Connect.Slack`, a Spark-authored provider that compiles into Jido tools
- generated actions for listing conversations, reading conversation history
  and thread replies, and posting, updating, and deleting messages
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

## Thread replies

`slack.thread.replies` reads one page of a thread through Slack
`conversations.replies`, with the bot or the user profile.

Inputs:

- `channel` and `ts`, the timestamp of the thread's parent message, are
  required.
- `conversation_type` is optional and takes `public_channel`,
  `private_channel`, `im` or `mpim`. It only selects the required scope
  (`channels:history`, `groups:history`, `im:history` or `mpim:history`) and
  is not sent to Slack. The action does not reject other values; they fall
  back to `channels:history`. Without it, the channel ID decides: a `G` ID
  needs `groups:history`, a `D` ID `im:history` and every other ID
  `channels:history`. Private channels and group DMs can carry `C` IDs, so
  pass the type for them.
- `cursor`, `oldest`, `latest` and `inclusive` (default `false`) go to Slack
  unchanged. `limit` defaults to 100.

One call sends one request and returns one page: `messages`, `reply_count`,
`latest_reply`, `has_more` and, while further pages follow, `next_cursor`.
`channel` and `thread_ts` repeat the input. To read the next page, pass
`next_cursor` as `cursor` with the same other inputs; on the last page
`has_more` is `false` and the output has no `next_cursor`. The action does not
read further pages on its own and does not retry. In the recordings of this
package, Slack puts the parent first on every page, followed by that page's
replies in ascending order, and the first page holds the newest replies.

`reply_count` and `latest_reply` come from the first message of the page,
which is the parent, when Slack sends them there. Otherwise the action counts
the replies on the page and takes the last `ts` of the page. Neither value
shows that the thread is complete or that the page holds every reply: a page
of two replies from a thread of 22 reports 22, and a computed value describes
only the returned page. A parent without replies comes back alone, with
`reply_count` 0 and its own `ts` as `latest_reply`.

Each message is a map with the keys `type`, `subtype`, `user`, `username`,
`bot_id`, `app_id`, `text`, `ts`, `thread_ts`, `parent_user_id`,
`reply_count`, `reply_users_count`, `latest_reply`, `blocks`, `files`,
`attachments` and `reactions`, holding Slack's values unchanged. A key whose
value Slack does not send or sends as an empty string is left out. Authors are
the IDs Slack sends: a person's reply has `user`, a bot's reply also `bot_id`
and `app_id`. `text` is the full text, also beyond 512 bytes.

An unknown `ts` is an error, not an empty page: Slack answers HTTP 200 with
`ok: false`, and the action returns a `Jido.Connect.Error.ProviderError` with
`reason` `"thread_not_found"`.

## Message delivery

`slack.message.post` sends `channel`, `text` and, when given, `thread_ts` to
Slack `chat.postMessage` unchanged, with `reply_broadcast` defaulting to
`false`. The text is Slack mrkdwn, so `<https://example.com|label>` arrives as
a link; the package does not escape, shorten or split it. `thread_ts` is the
string timestamp of the thread's parent message. Posting needs `chat:write`
and no history scope.

`slack.conversation.open` sends `users` to Slack `conversations.open` as a
comma-separated list and returns the conversation ID as `channel`, the target
for `slack.message.post`. One user opens the DM with the bot and needs
`im:write`; several users open a group DM and need `mpim:write`. To resume a
conversation by `channel`, the scope check reads only the ID: a `G` ID needs
`mpim:write`, every other ID `im:write`. Group DMs can also carry a `C` ID,
like the one in this package's recordings, and are then checked against
`im:write`; a token that resumes group DMs by `channel` should hold both
scopes. The action takes its client from a context `provider_client`, then
from the lease's `slack_client`, then `Jido.Connect.Slack.Client`, so a lease
with only an `access_token` works.

The package makes no delivery guarantee beyond Slack's answer:

- The returned `channel` and `ts` identify the message Slack stored. They are
  not read receipts and do not say that anyone saw the message or was
  notified.
- A successful response without `channel` or `ts` stays a success, and the
  output then lacks those fields. Check both before keeping a reference.
- Posting forwards no idempotency key, so every call that reaches Slack can
  post another message.
- The transport does not retry. After a timeout the error carries
  `delivery: :sent_outcome_unknown`, and the message may exist; look for it
  before posting again, with `slack.conversation.history` for a post and with
  `slack.thread.replies` for a thread reply, which the conversation history
  lists only when it is broadcast. A Slack `ok: false` answer, an HTTP error
  and a transport failure are separate `Jido.Connect.Error.ProviderError`s:
  `reason` is Slack's error code, `:http_error` with the HTTP `status`, or
  `:request_error`.

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
