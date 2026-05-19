defmodule Jido.Connect.Zendesk do
  @moduledoc """
  Zendesk integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Zendesk:

  - **API token** (`:api_token`): Zendesk API token used with the email address
    via Basic authentication (`email/token:api_token`). Recommended for
    server-to-server integrations, development, and CI.

  - **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
    Zendesk authorization server. Grants scoped access on behalf of a Zendesk
    user.

  ## Zendesk Scopes

  The provider declares Zendesk OAuth scopes:

  - `read` / `write`
  - `tickets:read` / `tickets:write`
  - `users:read`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Zendesk.Actions.Tickets
    ]

  defdelegate catalog_packs, to: Jido.Connect.Zendesk.CatalogPacks, as: :all

  integration do
    id(:zendesk)
    name("Zendesk")

    description(
      "Zendesk customer support platform for ticket management, customer communication, and help center."
    )

    category(:customer_support)
    docs(["https://developer.zendesk.com/api-reference/"])
  end

  catalog do
    package(:jido_connect_zendesk)
    status(:experimental)
    tags([:support, :tickets, :customer_service])

    capability :api_access do
      kind(:runtime)
      feature(:api_access)
      label("API access")
      description("Zendesk REST API access via API token or OAuth2.")
    end
  end

  auth do
    api_key :api_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Zendesk API token")
      setup :api_key_bearer_token
      credential_fields([:api_key, :email])
      lease_fields([:api_key])

      scopes([
        "read",
        "write",
        "tickets:read",
        "tickets:write",
        "users:read"
      ])

      default_scopes([
        "read",
        "tickets:read",
        "users:read"
      ])
    end

    oauth2 :oauth2 do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Zendesk OAuth user")
      authorize_url("https://:subdomain.zendesk.com/oauth/authorizations/new")
      token_url("https://:subdomain.zendesk.com/oauth/tokens")
      callback_path("/integrations/zendesk/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "read",
        "write",
        "tickets:read",
        "tickets:write",
        "users:read"
      ])

      default_scopes([
        "read",
        "tickets:read",
        "users:read"
      ])

      optional_scopes([
        "write",
        "tickets:write"
      ])

      pkce?(true)
      refresh?(true)
      revoke?(false)
    end
  end

  policies do
    policy :instance_access do
      label("Instance access")

      description(
        "Host verifies the actor may use this Zendesk connection for the requested instance."
      )

      subject({:input, :subdomain})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
