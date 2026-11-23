defmodule Jido.Connect.Tempo do
  @moduledoc """
  Tempo Cloud integration authored with the `Jido.Connect` Spark DSL.

  This module declares the provider, its two auth profiles and the five local
  labels that Tempo actions require. It has no actions yet; the client
  modules under `Jido.Connect.Tempo.Client` hold the connection contract and
  the transport that later actions use.

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

  use Jido.Connect, fragments: []

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
