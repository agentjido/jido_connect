defmodule Jido.Connect.Google.Meet do
  @moduledoc """
  Google Meet integration authored with the `Jido.Connect` Spark DSL.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Meet.Actions.Spaces,
      Jido.Connect.Google.Meet.Actions.ConferenceRecords,
      Jido.Connect.Google.Meet.Actions.Recordings,
      Jido.Connect.Google.Meet.Actions.Transcripts
    ]

  integration do
    id(:google_meet)
    name("Google Meet")
    description("Google Meet meeting space and conference record tools.")
    category(:collaboration)
    docs(["https://developers.google.com/workspace/meet/api/reference/rest"])
  end

  catalog do
    package(:jido_connect_google_meet)
    status(:experimental)
    tags([:google, :workspace, :meetings, :collaboration])
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
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Jido.Connect.Google.Scopes.user_default() ++
          Jido.Connect.Google.Scopes.product(:meet)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:meet))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
