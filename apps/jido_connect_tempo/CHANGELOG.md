# Changelog

## Unreleased

- Add the experimental Tempo provider package for Jido Connect, registered as
  `:tempo`, with the `:api_token` and `:oauth2_user` profiles and the labels
  `tempo.worklogs.read`, `tempo.worklogs.write`, `tempo.accounts.read`,
  `tempo.periods.read` and `tempo.approvals.read`.
- Add the connection contract: `provider: :tempo`, `subject.account_id` and
  one of the three Tempo API origins in `metadata.api_origin`.
- Add the Bearer transport with an origin guard, bounded offset pagination
  and error normalization to `ProviderError`.
- Add OAuth authorize URL, code exchange and refresh helpers; each refresh
  replaces both tokens.
- Add the scope resolver and the mapping of Tempo OAuth grants to labels.
- Add the read action `tempo.worklogs.list_own`, which returns every worklog
  of the connection's `subject.account_id` with a booking day in an
  inclusive date range, with `complete: true` for exhausted pagination. It
  requires `tempo.worklogs.read` and fails as a whole on a failed or
  malformed page, a malformed worklog, a foreign author or a booking day
  outside the range.
- Add `Jido.Connect.Tempo.Client.list_own_worklogs/2`, the normalized
  `Jido.Connect.Tempo.Worklog` and the read-only catalog pack
  `:tempo_reader`.
- Add the read action `tempo.period.bookability.get`, which returns the
  connection account's approval evidence for every Tempo period that
  intersects an inclusive date range: the part of the range in each period,
  the full period, the approval status as sent and its time, closure
  evidence `:unknown` and a derived state, `:blocked` for `IN_REVIEW` or
  `APPROVED`, else `:unknown`. It requires `tempo.periods.read` and
  `tempo.approvals.read`. A gap in period coverage, a failed approval read
  or an approval of another user or period sets `complete: false` and keeps
  the other segments' evidence; a failed approval read names its reason,
  status and `retry_after` in the segment's `approval_error`. A range of
  more than 20 periods fails with `:period_limit_exceeded` before the first
  approval read.
- Add `Jido.Connect.Tempo.Client.list_periods/2`,
  `Jido.Connect.Tempo.Client.get_timesheet_approval/3`, the normalized
  `Jido.Connect.Tempo.TimesheetApproval`, the result
  `Jido.Connect.Tempo.PeriodBookability` and the read-only catalog pack
  `:tempo_period_lookup`.
- Add the write action `tempo.worklog.create`, which creates one worklog of
  the connection's `subject.account_id` after confirmation and returns it as
  Tempo confirmed it. It declares `confirmation: :always`,
  `provider_idempotency?: false`, the host policy `:own_worklog_author` and
  the label `tempo.worklogs.write`, checks its input at prepare, in the
  handler and in the client, and sends one `POST /4/worklogs` without
  `bypassPeriodClosuresAndApprovals` or `remainingEstimateSeconds`.
- Add `Jido.Connect.Tempo.Client.create_worklog/2` and
  `Jido.Connect.Tempo.Client.Transport.post/3`. A POST is never retried, also
  when Req options enable retries; a 3xx, a 5xx, a malformed or mismatched
  success and a lost response are `delivery: :sent_outcome_unknown`, and
  Tempo's 403 `The timesheet status must be open for the period`, observed
  for an approved period, is `:period_locked`. A booking into a period in
  review or one closed in Period Management was not observed and may fail
  with `:forbidden` or `:bad_request`, also `delivery: :rejected` with
  `:do_not_retry`. Where Tempo's error text quotes the description, an
  attribute value or the author's account ID, the error holds `[redacted]`
  instead.
- Add the writer catalog pack `:tempo_writer`; the read packs are unchanged.
