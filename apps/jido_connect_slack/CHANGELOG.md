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
  `interactivity.interactivity_pointer` of workflow step interactions. No
  payload type is normalized yet.
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

## 0.1.0

- Add the initial Slack provider for Jido Connect with generated Jido modules,
  OAuth helpers, Web API client helpers, and signed request verification.
