defmodule Jido.Connect.MicrosoftOnedrive do
  @moduledoc """
  Microsoft OneDrive integration authored with the `Jido.Connect` Spark DSL.

  Reuses auth profiles, transport, and scope helpers from the shared
  `jido_connect_microsoft` foundation package.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.MicrosoftOnedrive.Actions.Read,
      Jido.Connect.MicrosoftOnedrive.Actions.Write,
      Jido.Connect.MicrosoftOnedrive.Actions.Destructive,
      Jido.Connect.MicrosoftOnedrive.Actions.Sharing,
      Jido.Connect.MicrosoftOnedrive.Actions.Permissions
    ]

  alias Jido.Connect.Microsoft.Scopes

  integration do
    id(:microsoft_onedrive)
    name("Microsoft OneDrive")

    description("Microsoft OneDrive file and folder tools via Microsoft Graph.")

    category(:file_storage)
    docs(["https://learn.microsoft.com/en-us/graph/api/resources/onedrive"])
  end

  catalog do
    package(:jido_connect_microsoft_onedrive)
    status(:available)
    tags([:microsoft, :onedrive, :files, :storage])
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Microsoft Graph OAuth user")
      authorize_url("https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
      token_url("https://login.microsoftonline.com/common/oauth2/v2.0/token")
      callback_path("/integrations/microsoft/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Scopes.user_default() ++
          Scopes.product(:files)
      )

      default_scopes(Scopes.user_default())
      optional_scopes(Scopes.product(:files))
      pkce?(true)
      refresh?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :all
  defdelegate metadata_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :metadata
  defdelegate triage_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :triage
  defdelegate write_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :write
  defdelegate destructive_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :destructive
  defdelegate sharing_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :sharing
  defdelegate admin_pack, to: Jido.Connect.MicrosoftOnedrive.CatalogPacks, as: :admin
end
