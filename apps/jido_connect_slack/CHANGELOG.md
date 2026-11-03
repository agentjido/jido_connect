# Changelog

## Unreleased

- Add `slack.conversation.history`, a read of one page of a public channel,
  private channel, DM or group DM for the bot and the user profile, with a
  required `conversation_type` that selects the history scope and a `limit`
  from 1 through 100. Add `Client.get_conversation_history/2` and the
  `Jido.Connect.Slack.Message` struct, which keeps full text, nested blocks,
  attachments and files, exact timestamps, author IDs, subtype and edit
  metadata. The reader and editor catalog packs include the action.
- Keep Slack's `Retry-After` header as `details.retry_after` on `ok: false`
  responses, such as a 429 `ratelimited`. This changes the error details of
  every Slack action. HTTP failures without an `ok: false` body and failed
  file content uploads still carry no `retry_after`.
- Add `Jido.Connect.Slack.Interactivity.verify_delivery/4`, which verifies a
  signed interactivity form body and returns a `WebhookDelivery`. Bodies above
  `:max_body_bytes` (default 256 KiB) fail before the signature check. The
  delivery ID is the lowercase hex SHA-256 of the raw body, and the payload
  drops `token`, `bot_access_token`, `response_url`, `response_urls` and
  `trigger_id`, as well as `response_urls` inside a submitted `view` and
  `interactivity.interactivity_pointer` of workflow step interactions.
  Options go on to a normalizer for the payload type; only `block_actions`
  has one. `Interactivity.normalize_signal/2` returns the signal of a
  verified delivery or the reason it has none.
- Add optional `blocks` to `slack.message.post`, sent to
  `chat.postMessage` unchanged; `text` stays required as the fallback, and
  a text-only post sends no `blocks`.
- Add `Jido.Connect.Slack.BlockAction` and the trigger
  `slack.interactivity.block_actions` with bot auth, the `:workspace_access`
  policy and no OAuth scope. A `block_actions` click on one button in a
  message becomes a signal with the clicking user from `user.id`, the
  message's `channel_id`, `message_ts` and `thread_ts`, and the button's
  `action_id`, `block_id` and opaque `value`. A value of up to 2,000
  characters and IDs of up to 255 are kept. Several actions, another
  element, another container or an ephemeral message fail with
  `:unsupported_block_action`, an org-wide install with `:no_workspace`, a
  missing or malformed field with `:invalid_block_action`, container and
  message IDs that disagree with `:conflicting_block_action`, and with the
  option `:api_app_id` a click for another app with `:unexpected_app`. Every
  such delivery still verifies, with `normalized_signal: nil`.
- Normalize the message subtypes `file_share` and `thread_broadcast` as new
  messages. Their signals carry `subtype`, and file shares also `file_ids`;
  a broadcast reply also reaches `slack.event.message.thread_reply`. Every
  other subtype still returns `:unsupported_message_subtype`, and plain
  messages carry no `subtype`.
- Add `shared_messages` to DM and group DM signals for messages shared
  natively into the conversation (`attachments[].is_share`), with source
  channel, `ts`, author as `user`, `text` and `from_url`. A malformed share
  fails with `:invalid_shared_message`. Group DMs take the DM path; no share
  into a group DM was captured.
- Pin message, DM, group DM, thread reply and app mention normalization with
  Events API deliveries captured from the test workspace.
- Add `slack.event.message.{channels,groups,im,mpim}.{changed,deleted}`,
  triggers for message edits and deletions on the existing message
  subscriptions, and `Jido.Connect.Slack.MessageChange`, the shape of their
  signal. Its `ts` is the edited or deleted message's `ts`, apart from the
  notification's. Edits keep their full text, also when it is empty, and
  their editor; deletions carry no text. A `message_changed` event without
  a new `message.edited`, such as an unfurl of a message edited before,
  returns `:not_an_edit`, a malformed change `:invalid_message_change` and
  a conflicting `previous_message` `:conflicting_message_change`. A deleted
  thread parent with replies, which Slack sends as a `message_changed` with
  a tombstone, becomes a deletion with the author from `previous_message`;
  the later removal of the tombstone becomes a second deletion without
  author. The generic `message` event and `normalize_event/1` now normalize
  both subtypes, so a verified edit or deletion carries a signal; the
  message triggers still reject them.
- Add the authorizing user's view. `OAuth.authorize_url/1` takes
  `:user_scope` and sends it as Slack's `user_scope`; without it the URL is
  unchanged. `OAuth.exchange_code/2` keeps the bot credential and adds
  `authed_user` when Slack returns a user token: `id`, `access_token`,
  `token_type`, `scope` and, with token rotation, `refresh_token`,
  `expires_in` and `expires_at`. A response with only a user token now
  yields `authed_user` without the bot fields instead of
  `:invalid_response`. `OAuth.user_credential_lease/3` leases the user
  token for the `:user` profile, never past the token's `expires_at` and
  without the refresh token.
- `OAuth.bot_credential_lease/3` returns an `AuthError` with reason
  `:missing_bot_credential` for a token without a bot token instead of
  raising, and a lease bound to `:connection` now takes that connection's
  ID instead of `slack-team-<team>`, so it matches the connection.
- Both lease functions refuse a `:connection` of another provider with
  reason `:credential_connection_mismatch`, and a `:connection` or
  `:profile` of the other profile with reason `:unsupported_auth_profile`.
  Before, `bot_credential_lease/3` took the profile of any connection or
  `:profile`, so a lease could carry one token under the other profile.
- Both lease functions read a token result with string keys, as from a
  JSON column, and the user token's `expires_at` as an ISO 8601 string.
  Any other `expires_at` returns `:invalid_user_credential` instead of
  being ignored. `connection_id: nil` and `expires_at: nil` mean the
  defaults.
- `AppManifest.build/2` takes `:user_scopes` for
  `oauth_config.scopes.user` and `:user_events` for
  `settings.event_subscriptions.user_events`; user events need
  `include_events?: true`. Manifests without the options are unchanged.
- Message signals of `slack.event.message.{channels,groups,im,mpim,thread_reply}`
  and the signals of the eight edit and deletion triggers carry `view`
  (`"bot"` or `"user"`) and `viewer` from the delivery's `authorizations`,
  and `MessageChange` has both fields. `shared_messages` stays in both
  views. A share with `view: "bot"` comes from the bot DM and hands the
  message to the app; one with `view: "user"` does so only when its
  `conversation.id` is the bot DM, since Slack does not document which
  view it names there.

## 0.1.0

- Add the initial Slack provider for Jido Connect with generated Jido modules,
  OAuth helpers, Web API client helpers, and signed request verification.
