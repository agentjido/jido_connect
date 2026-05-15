defmodule Jido.Connect.Google.Forms do
  @moduledoc """
  Google Forms integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Forms surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Forms.Actions.Forms
    ]

  integration do
    id(:google_forms)
    name("Google Forms")

    description(
      "Google Forms form creation, reading, response management, and collaboration tools."
    )

    category(:productivity)
    docs(["https://developers.google.com/forms/api"])
  end

  catalog do
    package(:jido_connect_google_forms)
    status(:experimental)
    tags([:google, :workspace, :forms, :surveys, :productivity])
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
          Jido.Connect.Google.Scopes.product(:forms)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:forms))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Forms.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Forms.CatalogPacks, as: :readonly
  defdelegate editor_pack, to: Jido.Connect.Google.Forms.CatalogPacks, as: :editor
end
