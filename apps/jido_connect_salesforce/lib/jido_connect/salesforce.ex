defmodule Jido.Connect.Salesforce do
  @moduledoc """
  Salesforce CRM integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Salesforce surface is implemented.

  ## Auth Profiles

  The provider supports two authentication profiles:

  - **OAuth2 connected-app** (`:oauth2_connected_app`): Standard OAuth2
    authorization code flow with PKCE against a Salesforce connected app.
    Recommended for production integrations. Grants scoped access on behalf of
    a Salesforce user.

  - **Username/password** (`:username_password`): Salesforce username-password
    OAuth flow for development and CI. Authenticates using org credentials
    directly.

  ## Instance URL

  Salesforce REST APIs are scoped to an org-specific instance URL
  (e.g., `https://myorg.my.salesforce.com`). The instance URL is obtained from
  the OAuth token response and must be stored as a credential field for use by
  the REST transport boundary.

  ## Salesforce OAuth Scopes

  The provider declares Salesforce OAuth scopes for CRM objects:

  - `api` — Access to Salesforce REST API
  - `refresh_token,offline_access` — Long-lived token refresh
  - `cdp_api` — Customer Data Platform access (optional)

  ## API Version

  The REST transport targets Salesforce API version `60.0` by default,
  configurable via application env.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Salesforce.Actions.Read,
      Jido.Connect.Salesforce.Actions.Write
    ]

  defdelegate catalog_packs, to: Jido.Connect.Salesforce.CatalogPacks, as: :all

  integration do
    id(:salesforce)
    name("Salesforce")
    description("Salesforce CRM contacts, accounts, opportunities, and leads.")
    category(:crm)
    docs(["https://developer.salesforce.com/docs/apis"])
  end

  catalog do
    package(:jido_connect_salesforce)
    status(:experimental)
    tags([:salesforce, :crm, :contacts, :accounts, :opportunities])
  end

  auth do
    oauth2 :oauth2_connected_app do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Salesforce OAuth connected-app")
      authorize_url("https://login.salesforce.com/services/oauth2/authorize")
      token_url("https://login.salesforce.com/services/oauth2/token")
      callback_path("/integrations/salesforce/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token, :instance_url])
      lease_fields([:access_token, :instance_url])

      scopes([
        "api",
        "refresh_token,offline_access",
        "cdp_api"
      ])

      default_scopes([
        "api",
        "refresh_token,offline_access"
      ])

      optional_scopes([
        "cdp_api"
      ])

      pkce?(true)
      refresh?(true)
    end

    oauth2 :username_password do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Salesforce username/password")
      authorize_url("https://login.salesforce.com/services/oauth2/authorize")
      token_url("https://login.salesforce.com/services/oauth2/token")
      callback_path("/integrations/salesforce/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_password)
      credential_fields([:access_token, :refresh_token, :instance_url])
      lease_fields([:access_token, :instance_url])

      scopes([
        "api",
        "refresh_token,offline_access"
      ])

      default_scopes([
        "api",
        "refresh_token,offline_access"
      ])

      refresh?(true)
    end
  end
end
