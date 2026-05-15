defmodule Jido.Connect.Google.SearchConsole do
  @moduledoc """
  Google Search Console integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Search Console surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.SearchConsole.Actions.Sites,
      Jido.Connect.Google.SearchConsole.Actions.SearchAnalytics
    ]

  integration do
    id(:google_search_console)
    name("Google Search Console")

    description(
      "Google Search Console site, search analytics, sitemap, and URL inspection tools."
    )

    category(:marketing)
    docs(["https://developers.google.com/webmaster-tools/v1"])
  end

  catalog do
    package(:jido_connect_google_search_console)
    status(:experimental)
    tags([:google, :workspace, :search, :seo, :marketing])
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
          Jido.Connect.Google.Scopes.product(:search_console)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:search_console))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
