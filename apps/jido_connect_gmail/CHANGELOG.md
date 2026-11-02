# Changelog

## Unreleased

- Require `gmail.readonly`, or an already granted `gmail.modify` or
  `https://mail.google.com/`, for `google.gmail.messages.list` and
  `google.gmail.threads.list` with a non-empty `query`, including a query of
  whitespace, which the client still sends as `q`. Gmail rejects `q` under
  `gmail.metadata`; list requests without a query, or with an empty one, keep
  the metadata-read resolution.

## 0.1.0

- Initial Gmail provider package scaffold.
