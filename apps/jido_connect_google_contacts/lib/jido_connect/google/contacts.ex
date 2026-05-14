defmodule Jido.Connect.Google.Contacts do
  @moduledoc """
  Google Contacts integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Contacts surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Contacts.Actions.Read,
      Jido.Connect.Google.Contacts.Actions.Batch,
      Jido.Connect.Google.Contacts.Actions.Directory,
      Jido.Connect.Google.Contacts.Actions.OtherContacts,
      Jido.Connect.Google.Contacts.Actions.Groups,
      Jido.Connect.Google.Contacts.Actions.Write,
      Jido.Connect.Google.Contacts.Triggers.People
    ]

  integration do
    id(:google_contacts)
    name("Google Contacts")
    description("Google Contacts people, contact, and contact group tools.")
    category(:crm)
    docs(["https://developers.google.com/people"])
  end

  catalog do
    package(:jido_connect_google_contacts)
    status(:experimental)
    tags([:google, :workspace, :contacts, :productivity])
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
          Jido.Connect.Google.Scopes.product(:contacts)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:contacts))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Contacts.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Contacts.CatalogPacks, as: :readonly
  defdelegate manager_pack, to: Jido.Connect.Google.Contacts.CatalogPacks, as: :manager
end
