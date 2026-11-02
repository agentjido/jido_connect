# Jido Connect Slack

`jido_connect_slack` is the Slack provider package for `jido_connect`.

It includes:

- `Jido.Connect.Slack`, a Spark-authored provider that compiles into Jido tools
- generated actions for listing conversations, reading conversation history
  and thread replies, and posting, updating, and deleting messages
- OAuth v2 helpers in `Jido.Connect.Slack.OAuth`
- Slack Web API helpers in `Jido.Connect.Slack.Client`
- signed request verification and Events API helpers in `Jido.Connect.Slack.Webhook`
- verification of signed interactivity requests and button clicks in
  `Jido.Connect.Slack.Interactivity`

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

`blocks` is optional and goes to Slack as given, so a post can carry Block
Kit layout such as buttons; [Buttons in messages](#buttons-in-messages)
shows an example. `text` stays required: Slack shows it in notifications
and in clients that cannot render the blocks. A post without `blocks` sends
no `blocks` key.

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

`Jido.Connect.Slack.Webhook.verify_delivery/4` returns a verified
`Jido.Connect.WebhookDelivery` whose delivery ID is Slack's `event_id`, so a
retry with `x-slack-retry-num` is a duplicate for `:seen_delivery_ids`.
Verification and normalization are separate: a delivery whose signature
verifies keeps `normalized_signal: nil` when the package does not normalize
its event, such as a join notice, a URL challenge or a `message_changed`
event that is no edit. The same holds when normalization fails, as for a
message with a malformed share. `Jido.Connect.Slack.Webhook.normalize_signal/2`
returns the reason, for example `:unsupported_message_subtype`,
`:not_an_edit` or `:invalid_shared_message`.

### Message events

The bot receives messages only from conversations it belongs to: public and
private channels it is a member of, its own DM, which needs the Messages tab
of the app's App Home, and group DMs that include it. A channel the bot has
left sends it nothing. Subscribe the app's bot events to:

| Slack subscription | Scope | Trigger |
| --- | --- | --- |
| `message.channels` | `channels:history` | `slack.event.message.channels` |
| `message.groups` | `groups:history` | `slack.event.message.groups` |
| `message.im` | `im:history` | `slack.event.message.im` |
| `message.mpim` | `mpim:history` | `slack.event.message.mpim` |
| `app_mention` | `app_mentions:read` | `slack.event.app_mention` |

The four message subscriptions all deliver Slack's `message` event, and its
`channel_type` (`channel`, `group`, `im`, `mpim`) selects the trigger. Thread
replies arrive through the same subscriptions: `slack.event.message.thread_reply`
has no subscription of its own and accepts a message whose `thread_ts`
differs from its `ts`. A thread parent and a message without `thread_ts` are
no thread reply.

`app_mention` concerns the bot only. When a person mentions the app in a
channel the bot belongs to, Slack sends two deliveries with the same `ts` and
their own `event_id`: an `app_mention` event and a `message` event. The
message signal keeps the mention as `<@U…>` text and is no app mention; a
host that handles both can match them by `channel` and `ts`.

The message triggers accept messages without a subtype and two subtypes of
new messages that people write:

- `file_share`, a message with files. A person uploads them with the
  message, or shares an existing file into the conversation with the file's
  own share action. That hands over the file, not the message it was posted
  with, so the signal has no `shared_messages`. The signal carries
  `subtype: "file_share"` and `file_ids`, the IDs from `files[].id`; file
  content, previews and links stay out of the signal. `conversations.history`
  returns the same message without the subtype.
- `thread_broadcast`, a thread reply also sent to the channel. It normalizes
  under the channel's trigger and under `slack.event.message.thread_reply`,
  with `subtype: "thread_broadcast"`.

Every other subtype, such as `channel_join` or `bot_message`, returns
`:unsupported_message_subtype`. So do `message_changed` and
`message_deleted`; edits and deletions have triggers of their own, see
[Edits and deletions](#edits-and-deletions).
Signals of plain messages carry no `subtype`. The subtype does not tell
people from bots: an app posting with `chat.postMessage` sends messages
without a subtype, and they normalize like a person's. To skip the bot's own
posts, compare `user` with the installation's bot user ID.

`text` is Slack's full text, also beyond 512 bytes, and IDs and timestamps
stay Slack's strings. DM and group DM signals add `conversation` (`id` and
`type`) and `sender` (`id`, and `team_id` only when Slack sends `user_team`
or `source_team`). The DMs captured from the test workspace carried neither,
so `sender` held only the ID; the package does not take the event's `team`
instead.

### Handing a message over

A person hands a message to the app by sharing it into the bot DM with
Slack's "Share message". Slack delivers a `message.im` event whose
`attachments` hold the shared message with `is_share: true`; the shares
captured from the test workspace had no subtype. The signal keeps the person
who shared as `user` and adds `shared_messages`, one entry per shared
attachment:

- `channel`, the conversation the message comes from,
- `ts`, the shared message's timestamp,
- `user`, its author, when Slack names one,
- `text`, its text,
- `from_url`, Slack's link to it.

The app sees only the shared message, not the rest of its conversation or
thread. An entry has no `thread_ts`: the package reads no thread from the
attachment, so for a shared thread reply only `from_url`, Slack's link to
the reply, names the thread. Group DM signals keep shares the same way,
through the same path as DMs.

The shares captured from the test workspace were the sharer's own top-level
messages from a public and a private channel, shared into the bot DM.
Shares of thread replies, of bot messages and of other authors' messages,
and shares into a group DM, were not captured.

A share without source channel or `ts`, a share field that is not a string,
or `attachments` that are not a list make normalization fail with
`:invalid_shared_message`, whose details name the payload path, never a
value. A DM without a shared attachment has no `shared_messages`. The
package declares no message shortcut.

### Edits and deletions

Slack reports an edit as a `message` event with the subtype
`message_changed` and a deletion as one with `message_deleted`, through the
same four subscriptions as new messages. Eight triggers take them, two per
conversation class:

| Slack subscription | Scope | Edit | Deletion |
| --- | --- | --- | --- |
| `message.channels` | `channels:history` | `slack.event.message.channels.changed` | `slack.event.message.channels.deleted` |
| `message.groups` | `groups:history` | `slack.event.message.groups.changed` | `slack.event.message.groups.deleted` |
| `message.im` | `im:history` | `slack.event.message.im.changed` | `slack.event.message.im.deleted` |
| `message.mpim` | `mpim:history` | `slack.event.message.mpim.changed` | `slack.event.message.mpim.deleted` |

They need no further subscription, scope or manifest event. Like the
message triggers, each takes only its own `channel_type`, and the public
channel triggers also take an event without one. The generic `message`
event and `normalize_event/1` take edits and deletions of every class; the
message triggers reject both subtypes.

Only a `message_changed` event whose `message` carries a new `edited` is an
edit. Slack sends the same subtype when it unfurls a link, when a thread
parent gets a new reply count and when a broadcast reply's thread root
changes. Slack keeps `edited` on a message after an edit, so such a change
of an edited message repeats the last edit. An edit therefore needs another
`edited.ts` than `previous_message.edited.ts`, or another text than
`previous_message.text`, since two edits within one second share their
`edited.ts`; without `previous_message`, `message.edited` alone marks an
edit. Every other `message_changed` event, apart from a tombstone, returns
`:not_an_edit`, and its verified delivery keeps `normalized_signal: nil`.

Slack reports the deletion of a thread parent that has replies as a
`message_changed` event whose `message` is a tombstone: it has the subtype
`tombstone`, Slackbot as `user` and no `edited`. The deletion triggers, the
generic `message` event and `normalize_event/1` turn it into a deletion
signal with the subtype `message_deleted`, whose `ts` and `thread_ts` come
from the tombstone and whose author comes from `previous_message`. The edit
triggers return `:not_an_edit` for it. When the thread's last reply is
deleted, Slack removes the tombstone with a `message_deleted` event whose
`previous_message` is the tombstone. That event yields a second deletion
signal for the same `ts`, with its own `event_id` and no author. The host
dedupes the deletions of one message by `channel` and `ts` if it needs to.

The signal, described by `Jido.Connect.Slack.MessageChange`, names the
original message by `channel` and `ts`: `message.ts` of an edit or a
tombstone and `deleted_ts` of a deletion. `notification_ts` and `event_ts`
belong to the notification. Every edit and deletion has its own
`event_id`, also two edits of one message, and the triggers dedupe on
`team_id` and `event_id`. IDs and timestamps stay Slack's strings.

- An edit carries the text after the edit as `text`, in full, and as `""`
  when Slack stores an empty text, as after an edit to an empty text beside
  an attachment; for an empty text beside blocks, Slack stores the blocks'
  text. It names the author as `user`, `bot_id` and `app_id`, the thread as
  `thread_ts`, and the editor and edit time from `message.edited` as
  `editor` and `edited_ts`. An edit through `chat.update` names the bot
  user as author and editor.
- A deletion carries no text. Its author and `thread_ts` come from
  `previous_message` when Slack sends it; without it the signal names only
  the message. A tombstone in `previous_message` gives `thread_ts` but no
  author. Slack does not say who deleted a message.

A missing or empty team, event, channel or source `ts`, a field that is no
string, or a `message` or `previous_message` that is no object fail with
`:invalid_message_change`. A `previous_message` whose `ts` differs from the
source `ts` fails with `:conflicting_message_change`. The details name
payload paths, never a value. The package does not order edits, apply them
to a stored message or drop deleted ones; the host can order the edits of
one message by `edited_ts`.

The changes captured from the test workspace were two edits and a deletion
of a message in each conversation class and of a thread reply, each by the
person who wrote it, and bot edits through `chat.update`, one of them to an
empty text beside an attachment. The deletion of a thread parent with
replies was captured for two bot messages deleted through `chat.delete`,
one of them after an edit, and the removal of both tombstones. An
edit by another person than the author, a deletion without
`previous_message`, a change that repeats an earlier edit and a person's
deletion of a thread parent with replies were not captured.

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
- `:api_app_id` names the host's Slack app. Only the `block_actions`
  normalizer reads it, as the next section describes; the transport does not
  check the app.

The signature and timestamp checks are those of
`Jido.Connect.Slack.Webhook.verify_signature/4` and return its auth errors. The
body must hold exactly one `payload` field whose JSON value is an object;
otherwise the error reason is `:missing_payload`, `:duplicate_payload` or
`:invalid_payload`.

Slack sends no delivery ID with interactivity requests. The delivery ID is the
lowercase hex SHA-256 of the verified raw body. A byte-identical redelivery
gets the same ID and is marked `duplicate?: true` when that ID is in
`:seen_delivery_ids`; a body that differs in any byte gets another ID. The
ID, `duplicate?` and `received_at` stay on the delivery. Unlike a signal from
`Jido.Connect.Slack.Webhook.normalize_signal/1`, an interactivity signal
carries no `delivery` map, so a host that handles both reads `delivery_id`
from the `WebhookDelivery`.

`event` is the payload `type`, and `metadata` carries `team_id` and
`api_app_id`. `payload` is the decoded object without the temporary
capabilities `token`, `bot_access_token`, `response_url`, `response_urls` and
`trigger_id`. A `view_submission` can also carry `response_urls` inside `view`,
and an interaction from a workflow step carries
`interactivity.interactivity_pointer`; both are dropped as well. `interactor`
and `function_data` stay. The raw body is not kept. Only `block_actions`
payloads are normalized, as the next section describes; every other payload
keeps `normalized_signal: nil`.
Verification makes no HTTP request and does not acknowledge the request; the
host answers Slack.

### Buttons in messages

A message with buttons is a post with `blocks` and a fallback `text`. Each
button carries an `action_id`, the `block_id` of its actions block and an
opaque `value` that the host chooses, such as a correlation key:

```elixir
Jido.Connect.invoke(
  Jido.Connect.Slack,
  "slack.message.post",
  %{
    channel: "C012AB3CD",
    text: "Request 42: Approve or Reject",
    blocks: [
      %{type: "section", text: %{type: "mrkdwn", text: "*Request 42*"}},
      %{
        type: "actions",
        block_id: "request_42",
        elements: [
          %{
            type: "button",
            action_id: "approve",
            text: %{type: "plain_text", text: "Approve"},
            value: "request-42:approve"
          },
          %{
            type: "button",
            action_id: "reject",
            text: %{type: "plain_text", text: "Reject"},
            value: "request-42:reject"
          }
        ]
      }
    ]
  },
  context: context,
  credential_lease: lease
)
```

A click arrives at the interactivity request URL as a signed `block_actions`
payload. `verify_delivery/4` sets `normalized_signal` to the fields of
`Jido.Connect.Slack.BlockAction`, without those that are `nil`, when the
click is on one button in a message:

```elixir
{:ok, delivery} =
  Jido.Connect.Slack.Interactivity.verify_delivery(raw_body, headers, signing_secret,
    api_app_id: "A012AB3CD",
    seen_delivery_ids: processed_ids
  )

%{user_id: user, channel_id: channel, message_ts: ts, value: value} =
  delivery.normalized_signal
```

`user_id` is the person who clicked. It comes from `user.id`, not from the
message's `user`, and is the message's author or the app's installer only
when that person clicked; the host decides who may click. `channel_id`,
`message_ts` and, when Slack sends it, `thread_ts` name the message that
holds the button; `action_id`, `block_id` and `value` are the button's, and
`action_ts` is the time of the click. `api_app_id`, `team_id`,
`user_team_id` and, for a workspace in an enterprise organization,
`enterprise_id` come with them. IDs, timestamps and the value stay Slack's
exact strings. A `value` may have up to 2,000 characters and an `action_id`
or `block_id` up to 255, as Slack allows; a longer one fails. The trigger
`slack.interactivity.block_actions` declares this signal with bot auth, the
`:workspace_access` policy and no OAuth scope beyond the app's install, and
dedupes on `team_id`, `channel_id`, `message_ts`, `user_id`, `block_id`,
`action_id`, `value` and `action_ts`.

A click on several actions, on another element such as a select, or outside
a message, as in a modal or a legacy attachment, keeps
`normalized_signal: nil`. A button in an ephemeral message, such as one
posted with `slack.message.post_ephemeral`, gets no signal either: Slack
sends that click with `container.is_ephemeral: true` and without the
message. Neither does an org-wide install, which sends no workspace; the
package takes only apps installed in a workspace. Call
`Jido.Connect.Slack.Interactivity.normalize_signal/2` on such a delivery,
with the same options, for a `Jido.Connect.Error.ProviderError` that names
the reason and the payload path, never a value:

- `:unsupported_block_action` for several actions, another element,
  another container or an ephemeral message;
- `:no_workspace` for an org-wide install or a payload without `team.id`;
- `:invalid_block_action` for a missing or empty field, a value that is no
  string, or a value or ID over the limit;
- `:conflicting_block_action` when the container and the message name
  different channels, messages or threads;
- `:unexpected_app` when `:api_app_id` is given and the click is for another
  app.

A click for another app still verifies, without a signal and without an
error, because only the normalizer reads `:api_app_id`. A wrong
`:api_app_id` in the host's configuration therefore drops every click
silently; `metadata.api_app_id` of the delivery shows the app Slack named.

`Jido.Connect.WebhookDelivery.to_public_map/1`, and with it `inspect/2` of a
delivery, bounds every binary at 512 bytes by design, so a long `value`
appears there truncated. The full value is in `normalized_signal` and in the
`Jido.Connect.Slack.BlockAction` struct, which `BlockAction.new/1` builds
from the signal. The package does not call `response_url`, update the
message or attach any meaning to a click; the host decides what a value
stands for, who may click and until when.

Two clicks of a person on bot messages in the test workspace were captured
and replay offline. A click by a second person, a button in a thread, a
workspace in an enterprise organization and the error cases are derived from
those captures.
