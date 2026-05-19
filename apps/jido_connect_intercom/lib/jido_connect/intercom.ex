defmodule Jido.Connect.Intercom do
  @moduledoc """
  Intercom integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Intercom:

  - **Access token** (`:access_token`): Intercom personal access token sent via
    the `Authorization: Bearer <token>` header. Recommended for server-to-server
    integrations, development, and CI.

  - **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
    Intercom authorization server. Grants scoped access on behalf of an Intercom
    workspace admin.

  ## Intercom Scopes

  The provider declares Intercom permission scopes:

  - `contacts:read` / `contacts:write`
  - `conversations:read` / `conversations:write`
  - `companies:read` / `companies:write`
  - `admins:read`
  - `tags:read` / `tags:write`
  """

  use Jido.Connect, fragments: []

  defdelegate catalog_packs, to: Jido.Connect.Intercom.CatalogPacks, as: :all

  integration do
    id(:intercom)
    name("Intercom")

    description(
      "Intercom customer messaging platform for conversations, contacts, companies, and support workflows."
    )

    category(:customer_support)
    docs(["https://developers.intercom.com/docs/references/"])
  end

  catalog do
    package(:jido_connect_intercom)
    status(:experimental)
    tags([:support, :messaging, :customer_service])

    capability :api_access do
      kind(:runtime)
      feature(:api_access)
      label("API access")
      description("Intercom REST API access via access token or OAuth2.")
    end
  end

  auth do
    api_key :access_token do
      default?(true)
      owner(:app_user)
      subject(:admin)
      label("Intercom access token")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "contacts:read",
        "contacts:write",
        "conversations:read",
        "conversations:write",
        "companies:read",
        "companies:write",
        "admins:read",
        "tags:read",
        "tags:write"
      ])

      default_scopes([
        "contacts:read",
        "conversations:read",
        "companies:read",
        "admins:read",
        "tags:read"
      ])
    end

    oauth2 :oauth2 do
      default?(false)
      owner(:app_user)
      subject(:admin)
      label("Intercom OAuth admin")
      authorize_url("https://app.intercom.com/oauth")
      token_url("https://api.intercom.io/auth/eagle/token")
      callback_path("/integrations/intercom/oauth/callback")
      token_field(:access_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token])
      lease_fields([:access_token])

      scopes([])

      default_scopes([])

      pkce?(true)
      refresh?(false)
      revoke?(false)
    end
  end

  policies do
    policy :workspace_access do
      label("Workspace access")

      description(
        "Host verifies the actor may use this Intercom connection for the requested workspace."
      )

      decision(:allow_operation)
    end
  end
end
