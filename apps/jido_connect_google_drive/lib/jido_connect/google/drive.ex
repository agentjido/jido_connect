defmodule Jido.Connect.Google.Drive do
  @moduledoc """
  Google Drive integration authored with the `Jido.Connect` Spark DSL.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Drive.Actions.Read,
      Jido.Connect.Google.Drive.Actions.Write,
      Jido.Connect.Google.Drive.Actions.FileContent,
      Jido.Connect.Google.Drive.Actions.Permissions,
      Jido.Connect.Google.Drive.Actions.Watch,
      Jido.Connect.Google.Drive.Triggers.Changes
    ]

  integration do
    id(:google_drive)
    name("Google Drive")
    description("Google Drive file, folder, permission, export, and change tools.")
    category(:productivity)
    docs(["https://developers.google.com/drive/api/guides/about-sdk"])
  end

  catalog do
    package(:jido_connect_google_drive)
    status(:available)
    tags([:google, :workspace, :files, :productivity])
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
          Jido.Connect.Google.Scopes.product(:drive)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end

    service_account :service_account do
      owner(:system)
      subject(:service_account)
      label("Google service account")
      setup(:google_service_account_jwt)
      credential_fields([:client_email, :private_key, :private_key_id])
      lease_fields([:access_token])
      scopes(Jido.Connect.Google.Scopes.product(:drive))
      default_scopes([])
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
    end

    domain_delegated_service_account :domain_delegated_service_account do
      owner(:tenant)
      subject(:workspace_user)
      label("Google domain-delegated service account")
      setup(:google_domain_wide_delegation)
      credential_fields([:client_email, :private_key, :private_key_id, :subject])
      lease_fields([:access_token])
      scopes(Jido.Connect.Google.Scopes.product(:drive))
      default_scopes([])
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Drive.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :readonly
  defdelegate file_writer_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :file_writer
  defdelegate watch_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :watch
end
