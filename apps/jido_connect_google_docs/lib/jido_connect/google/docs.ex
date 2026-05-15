defmodule Jido.Connect.Google.Docs do
  @moduledoc """
  Google Docs integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Docs surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Docs.Actions.Documents
    ]

  integration do
    id(:google_docs)
    name("Google Docs")

    description("Google Docs document creation, editing, reading, and collaboration tools.")

    category(:productivity)
    docs(["https://developers.google.com/docs/api"])
  end

  catalog do
    package(:jido_connect_google_docs)
    status(:experimental)
    tags([:google, :workspace, :docs, :documents, :productivity])
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
          Jido.Connect.Google.Scopes.product(:docs)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:docs))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
