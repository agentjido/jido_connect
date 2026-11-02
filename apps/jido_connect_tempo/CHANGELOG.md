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
