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

## 0.1.0

- Add the initial Slack provider for Jido Connect with generated Jido modules,
  OAuth helpers, Web API client helpers, and signed request verification.
