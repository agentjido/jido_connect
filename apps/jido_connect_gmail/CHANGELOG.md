# Changelog

## Unreleased

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
