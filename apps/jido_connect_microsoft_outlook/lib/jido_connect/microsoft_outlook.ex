defmodule Jido.Connect.MicrosoftOutlook do
  @moduledoc """
  Microsoft Outlook Mail integration authored with the `Jido.Connect` Spark DSL.

  Reuses auth profiles, transport, and scope helpers from the shared
  `jido_connect_microsoft` foundation package.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.MicrosoftOutlook.Actions.Read,
      Jido.Connect.MicrosoftOutlook.Actions.Write,
      Jido.Connect.MicrosoftOutlook.Actions.Destructive
    ]

  alias Jido.Connect.Microsoft.Scopes

  integration do
    id(:microsoft_outlook)
    name("Microsoft Outlook Mail")

    description(
      "Microsoft Outlook Mail message, draft, folder, send, and move tools via Microsoft Graph."
    )

    category(:email)
    docs(["https://learn.microsoft.com/en-us/graph/api/resources/mail-api-overview"])
  end

  catalog do
    package(:jido_connect_microsoft_outlook)
    status(:available)
    tags([:microsoft, :outlook, :email, :productivity])
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
          Scopes.product(:mail)
      )

      default_scopes(Scopes.user_default())
      optional_scopes(Scopes.product(:mail))
      pkce?(true)
      refresh?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.MicrosoftOutlook.CatalogPacks, as: :all
  defdelegate metadata_pack, to: Jido.Connect.MicrosoftOutlook.CatalogPacks, as: :metadata
  defdelegate triage_pack, to: Jido.Connect.MicrosoftOutlook.CatalogPacks, as: :triage
  defdelegate send_pack, to: Jido.Connect.MicrosoftOutlook.CatalogPacks, as: :send
  defdelegate destructive_pack, to: Jido.Connect.MicrosoftOutlook.CatalogPacks, as: :destructive
end
