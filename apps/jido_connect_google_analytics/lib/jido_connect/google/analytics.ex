defmodule Jido.Connect.Google.Analytics do
  @moduledoc """
  Google Analytics integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Analytics surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Analytics.Actions.Metadata
    ]

  integration do
    id(:google_analytics)
    name("Google Analytics")
    description("Google Analytics 4 metadata and reporting tools.")
    category(:marketing)
    docs(["https://developers.google.com/analytics/devguides/reporting/data/v1"])
  end

  catalog do
    package(:jido_connect_google_analytics)
    status(:experimental)
    tags([:google, :workspace, :analytics, :reporting])
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Google OAuth user")
      authorize_url("https://accounts.google.com/o/oauth2/v2/auth")
      token_url("https://oauth2.googleapis.com/token")
      callback_path("/integrations/google/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Jido.Connect.Google.Scopes.user_default() ++
          Jido.Connect.Google.Scopes.product(:analytics)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:analytics))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
