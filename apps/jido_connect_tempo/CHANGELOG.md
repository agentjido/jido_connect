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
