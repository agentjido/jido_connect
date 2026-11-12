# Changelog

## Unreleased

- Add the poll trigger `google.gmail.message.changed`. It requests Gmail
  history from the stored checkpoint with the `historyTypes`
  `messageDeleted`, `labelAdded` and `labelRemoved`, drains every page and
  emits one signal per deleted message and per label change with
  `change_type`, `message_id`, `thread_id`, `history_id`,
  `changed_label_ids` and `label_ids`, and no message content. Config:
  `page_size`, default 100, and an optional `label_id`. It needs
  `gmail.metadata`, starts from the profile `historyId` without replay and
  returns `Jido.Connect.Google.Checkpoint` errors with reset guidance for an
  expired history ID and a repeated `nextPageToken`. The README describes how
  archive, Trash, restore and permanent delete appear.
- Both history poll triggers share one poller for profile initialization,
  page draining, the repeated-token guard and the expired-checkpoint error.
  `google.gmail.message.received` keeps its config, signals and behavior.
- Fix `google.gmail.message.trash`, `google.gmail.message.untrash`,
  `google.gmail.thread.trash` and `google.gmail.thread.untrash`, which sent a
  POST without a body and so without `Content-Length`; Google rejected it
  with HTTP 411. The requests now carry an empty body.
- Add `google.gmail.message.attachment.content.get`. It selects one
  attachment of a message by Gmail `partId`, an enclosed `message/rfc822`
  original included, and returns `Jido.Connect.Gmail.AttachmentContent` with
  the message, thread and part identity and Gmail's base64url `data`. Data
  that Gmail keeps behind an `attachmentId` is fetched with `attachments.get`,
  also when empty `data` sits next to the ID; inline data needs no further
  request. The data must decode to the part's `size`. Gmail converts
  inline `text/*` data to UTF-8 and keeps the original bytes only in
  `format=raw`, so such data is returned only when the conversion cannot have
  changed it: empty data, UTF-8 text, and 7-bit text in US-ASCII or an
  ASCII-compatible single-byte charset. Other inline text fails with
  `:attachment_converted`. The action requires `gmail.readonly`, or
  an already granted `gmail.modify` or `https://mail.google.com/`, and joins
  the `:google_gmail_content` pack. `google.gmail.message.attachment.get` and
  `Jido.Connect.Gmail.Attachment` are unchanged.
- Add `Jido.Connect.Gmail.MIME.Traversal.attachment/3`, which selects a part
  by `partId` under the traversal bounds, `verify_attachment_data/2` and
  `Jido.Connect.Gmail.MIME.Charset.canonical/1`.
- Add `google.gmail.message.content.get` and `google.gmail.thread.content.get`.
  Both read Gmail's `format=full` representation and return
  `Jido.Connect.Gmail.MessageContent` and `Jido.Connect.Gmail.ThreadContent`
  with every header, the body text parts, the attachment manifest and the
  enclosed `message/rfc822` messages. A body text part stored behind an
  `attachmentId` is fetched with `attachments.get`; file attachments are not
  fetched. Thread messages are ordered by numeric `internalDate`, and
  `max_messages`, default 100, bounds a thread. Both require `gmail.readonly`,
  or an already granted `gmail.modify` or `https://mail.google.com/`, and join
  the `:google_gmail_content` pack. The metadata actions and their structs are
  unchanged.
- Add `Jido.Connect.Gmail.MIME.Traversal`, a network-free walk over Gmail
  `format=full` payloads. It returns body text parts, an attachment manifest
  keyed by Gmail `partId`, nested `message/rfc822` messages and the text parts
  stored behind an `attachmentId`, with `max_depth` and `max_parts` bounds.
  Gmail returns `format=full` text data already converted to UTF-8; bytes
  fetched with `attachments.get` decode as UTF-8, US-ASCII, ISO-8859-1,
  ISO-8859-15 or Windows-1252, also under their IANA aliases, without a new
  dependency.
- Add the opt-in `:google_gmail_content` catalog pack and
  `Jido.Connect.Gmail.content_pack/0` with the metadata tools and
  `google.gmail.message.attachment.get`. Existing packs are unchanged.
- Require `gmail.readonly`, or an already granted `gmail.modify` or
  `https://mail.google.com/`, for `google.gmail.messages.list` and
  `google.gmail.threads.list` with a non-empty `query`, including a query of
  whitespace, which the client still sends as `q`. Gmail rejects `q` under
  `gmail.metadata`; list requests without a query, or with an empty one, keep
  the metadata-read resolution.

## 0.1.0

- Initial Gmail provider package scaffold.
