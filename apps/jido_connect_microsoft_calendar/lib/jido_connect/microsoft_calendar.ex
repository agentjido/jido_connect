defmodule Jido.Connect.MicrosoftCalendar do
  @moduledoc """
  Microsoft Calendar integration authored with the `Jido.Connect` Spark DSL.

  Reuses auth profiles, transport, and scope helpers from the shared
  `jido_connect_microsoft` foundation package.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.MicrosoftCalendar.Actions.Read,
      Jido.Connect.MicrosoftCalendar.Actions.Write,
      Jido.Connect.MicrosoftCalendar.Actions.Destructive
    ]

  alias Jido.Connect.Microsoft.Scopes

  integration do
    id(:microsoft_calendar)
    name("Microsoft Calendar")

    description("Microsoft Calendar calendar and event tools via Microsoft Graph.")

    category(:calendar)
    docs(["https://learn.microsoft.com/en-us/graph/api/resources/calendar"])
  end

  catalog do
    package(:jido_connect_microsoft_calendar)
    status(:available)
    tags([:microsoft, :calendar, :scheduling, :productivity])
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
          Scopes.product(:calendar)
      )

      default_scopes(Scopes.user_default())
      optional_scopes(Scopes.product(:calendar))
      pkce?(true)
      refresh?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.MicrosoftCalendar.CatalogPacks, as: :all
  defdelegate metadata_pack, to: Jido.Connect.MicrosoftCalendar.CatalogPacks, as: :metadata
  defdelegate triage_pack, to: Jido.Connect.MicrosoftCalendar.CatalogPacks, as: :triage
  defdelegate write_pack, to: Jido.Connect.MicrosoftCalendar.CatalogPacks, as: :write
  defdelegate destructive_pack, to: Jido.Connect.MicrosoftCalendar.CatalogPacks, as: :destructive
end
