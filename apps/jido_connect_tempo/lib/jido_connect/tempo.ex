defmodule Jido.Connect.Tempo do
  @moduledoc """
  Tempo Cloud integration authored with the `Jido.Connect` Spark DSL.

  This module declares the provider, its two auth profiles, the five local
  labels that Tempo actions require, the two read actions, the write action
  and its host policy. The client modules under `Jido.Connect.Tempo.Client`
  hold the connection contract, the transport and the provider calls.

  ## Own Worklogs

  `tempo.worklogs.list_own` returns every worklog of the connection's
  `subject.account_id` with a booking day from `from` to `to`, both
  inclusive, as `Jido.Connect.Tempo.Worklog` maps. The input selects only the
  range, never an account. The read requires `tempo.worklogs.read` and fails
  as a whole on any failed or malformed page, malformed worklog, foreign
  author or booking day outside the range; `complete: true` marks exhausted
  pagination. `issue_id` is the numeric Jira issue ID, readable with
  `jira.issue.get`.

  ## Period Bookability

  `tempo.period.bookability.get` returns, for the connection's
  `subject.account_id` and an inclusive range from `from` to `to`, the
  approval evidence of every Tempo period that intersects the range, with
  closure evidence `:unknown` and a state derived from the evidence. It
  reads `GET /4/periods` once and the user's approval once per intersecting
  period, at most 20, with that period's exact boundaries, and requires
  `tempo.periods.read` and `tempo.approvals.read`. See
  `Jido.Connect.Tempo.PeriodBookability` for the evidence, `complete` and
  the derivation. The result is neither a reservation nor a write
  guarantee.

  ## Worklog Creation

  `tempo.worklog.create` creates one worklog for the connection's
  `subject.account_id` and returns it as Tempo confirmed it. It requires
  `tempo.worklogs.write` and confirmation (`confirmation: :always`), and
  declares the host policy `:own_worklog_author`; the input's
  `author_account_id` must equal `subject.account_id`. The core allows
  direct mutation calls unless the host sets `direct_mutation_mode: :deny`,
  so a strict host creates through `Jido.Connect.prepare/4` and
  `Jido.Connect.commit/4`. The client sends one `POST /4/worklogs`, never
  retries it and reports a 3xx, a 5xx, a malformed or mismatched success
  and a lost response as `delivery: :sent_outcome_unknown`. Tempo's 403
  `The timesheet status must be open for the period`, observed for a
  booking into an approved period, fails with `:period_locked`. A booking
  into a period in review or one closed in Period Management was not
  observed and may fail with `:forbidden` or `:bad_request` instead; all
  three are `delivery: :rejected` with `:do_not_retry`. See
  `Jido.Connect.Tempo.Client.WorklogCreate`.

  ## Auth Profiles

  - **API token** (`:api_token`): a user-owned Tempo API token, leased as
    `api_token` and sent as a Bearer token.
  - **OAuth2** (`:oauth2_user`): the Tempo OAuth 2.0 authorization code flow,
    leased as `access_token` and sent as a Bearer token. See
    `Jido.Connect.Tempo.OAuth`.

  ## Labels

  `tempo.worklogs.read`, `tempo.worklogs.write`, `tempo.accounts.read`,
  `tempo.periods.read` and `tempo.approvals.read`. A label counts only when
  the host has recorded it in `connection.scopes`; see
  `Jido.Connect.Tempo.ScopeResolver`.
  """

  use Jido.Connect,
    fragments: [Jido.Connect.Tempo.Actions.Worklogs, Jido.Connect.Tempo.Actions.Periods]

  defdelegate catalog_packs, to: Jido.Connect.Tempo.CatalogPacks, as: :all

  @labels Jido.Connect.Tempo.ScopeResolver.labels()
  @read_labels @labels -- ["tempo.worklogs.write"]

  integration do
    id(:tempo)
    name("Tempo")
    description("Tempo Cloud timesheets: worklogs, accounts, periods and approvals.")
    category(:project_management)
    docs(["https://apidocs.tempo.io/"])
  end

  catalog do
    package(:jido_connect_tempo)
    status(:experimental)
    tags([:time_tracking, :worklogs, :project_management])
  end

  policies do
    policy :own_worklog_author do
      label("Own worklog author")

      description(
        "Host verifies the actor may book time as the connection's own Tempo user. The " <>
          "action itself accepts only author_account_id equal to subject.account_id."
      )

      subject({:input, :author_account_id})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end

  auth do
    api_key :api_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Tempo API token")
      setup(:api_key_bearer_token)
      credential_fields([:api_token])
      lease_fields([:api_token])
      scopes(@labels)
      default_scopes(@read_labels)
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Tempo OAuth user")
      authorize_url("https://api.tempo.io/oauth/authorize/redirect")
      token_url("https://api.tempo.io/oauth/token/")
      callback_path("/integrations/tempo/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])
      scopes(@labels)
      default_scopes(@read_labels)
      pkce?(false)
      refresh?(true)
      revoke?(false)
    end
  end
end
