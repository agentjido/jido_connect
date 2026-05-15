defmodule Jido.Connect.Google.Tasks do
  @moduledoc """
  Google Tasks integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Tasks surface is implemented.
  """

  use Jido.Connect

  integration do
    id(:google_tasks)
    name("Google Tasks")

    description("Google Tasks task list and task management tools.")

    category(:productivity)
    docs(["https://developers.google.com/tasks"])
  end

  catalog do
    package(:jido_connect_google_tasks)
    status(:experimental)
    tags([:google, :workspace, :tasks, :productivity])
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
          Jido.Connect.Google.Scopes.product(:tasks)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:tasks))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Tasks.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Tasks.CatalogPacks, as: :readonly
  defdelegate editor_pack, to: Jido.Connect.Google.Tasks.CatalogPacks, as: :editor
end
