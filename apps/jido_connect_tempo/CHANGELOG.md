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
