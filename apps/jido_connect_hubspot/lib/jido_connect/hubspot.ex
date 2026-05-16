defmodule Jido.Connect.HubSpot do
  @moduledoc """
  HubSpot CRM integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  HubSpot surface is implemented.

  ## Auth Profiles

  The provider supports two authentication profiles:

  - **Private app token** (`:private_app_token`): HubSpot private app access
    token passed as a Bearer token. Recommended for server-to-server integrations,
    development, and CI.

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
    PKCE. Grants scoped access on behalf of a HubSpot user.

  ## HubSpot Scopes

  The provider declares HubSpot CRM scopes for contacts, companies, deals,
  and tickets:

  - `crm.objects.contacts.read` / `crm.objects.contacts.write`
  - `crm.objects.companies.read` / `crm.objects.companies.write`
  - `crm.objects.deals.read` / `crm.objects.deals.write`
  - `crm.objects.tickets.read` / `crm.objects.tickets.write`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.HubSpot.Actions.Read,
      Jido.Connect.HubSpot.Actions.Write
    ]

  integration do
    id(:hubspot)
    name("HubSpot")
    description("HubSpot CRM contacts, companies, deals, and tickets.")
    category(:crm)
    docs(["https://developers.hubspot.com/docs/api/overview"])
  end

  catalog do
    package(:jido_connect_hubspot)
    status(:experimental)
    tags([:hubspot, :crm, :contacts, :deals])
  end

  auth do
    api_key :private_app_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("HubSpot private app token")
      setup(:api_key_bearer_token)
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "crm.objects.contacts.read",
        "crm.objects.contacts.write",
        "crm.objects.companies.read",
        "crm.objects.companies.write",
        "crm.objects.deals.read",
        "crm.objects.deals.write",
        "crm.objects.tickets.read",
        "crm.objects.tickets.write"
      ])

      default_scopes([
        "crm.objects.contacts.read",
        "crm.objects.companies.read",
        "crm.objects.deals.read",
        "crm.objects.tickets.read"
      ])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("HubSpot OAuth user")
      authorize_url("https://app.hubspot.com/oauth/authorize")
      token_url("https://api.hubapi.com/oauth/v1/token")
      callback_path("/integrations/hubspot/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "crm.objects.contacts.read",
        "crm.objects.contacts.write",
        "crm.objects.companies.read",
        "crm.objects.companies.write",
        "crm.objects.deals.read",
        "crm.objects.deals.write",
        "crm.objects.tickets.read",
        "crm.objects.tickets.write"
      ])

      default_scopes([
        "crm.objects.contacts.read",
        "crm.objects.companies.read",
        "crm.objects.deals.read",
        "crm.objects.tickets.read"
      ])

      optional_scopes([
        "crm.objects.contacts.write",
        "crm.objects.companies.write",
        "crm.objects.deals.write",
        "crm.objects.tickets.write"
      ])

      pkce?(true)
      refresh?(true)
    end
  end
end
