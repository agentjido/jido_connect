defmodule Jido.Connect.Notion do
  @moduledoc """
  Notion integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Notion:

  - **Internal integration token** (`:internal_token`): Notion internal
    integration token sent via the `Authorization: Bearer <token>` header.
    Created in the Notion workspace integrations settings. Recommended for
    server-to-server integrations, development, and CI. Internal integration
    tokens have access to all pages and databases the integration has been
    explicitly granted access to.

  - **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
    Notion authorization server. Grants scoped access on behalf of a Notion
    workspace user. Public integrations use this flow to request access to
    specific capabilities within a user's workspace.

  ## Notion Scopes

  The provider declares Notion permission scopes:

  - `read_content` / `insert_content` / `update_content`
  - `read_comments` / `insert_comments`
  - `read_databases` / `insert_databases` / `update_databases`
  - `read_users`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Notion.Actions.Read,
      Jido.Connect.Notion.Actions.Write
    ]

  defdelegate catalog_packs, to: Jido.Connect.Notion.CatalogPacks, as: :all

  integration do
    id(:notion)
    name("Notion")

    description("Notion workspace productivity platform for pages, databases, and content.")

    category(:productivity)
    docs(["https://developers.notion.com/reference"])
  end

  catalog do
    package(:jido_connect_notion)
    status(:experimental)
    tags([:productivity, :documents, :databases, :notes, :knowledge])

    capability :api_access do
      kind(:runtime)
      feature(:api_access)
      label("API access")
      description("Notion REST API access via internal integration token or OAuth2.")
    end
  end

  auth do
    api_key :internal_token do
      default?(true)
      owner(:app_user)
      subject(:workspace)
      label("Notion internal integration token")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "read_content",
        "insert_content",
        "update_content",
        "read_comments",
        "insert_comments",
        "read_databases",
        "insert_databases",
        "update_databases",
        "read_users"
      ])

      default_scopes([
        "read_content",
        "read_databases",
        "read_users"
      ])
    end

    oauth2 :oauth2 do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Notion OAuth user")
      authorize_url("https://api.notion.com/v1/oauth/authorize")
      token_url("https://api.notion.com/v1/oauth/token")
      callback_path("/integrations/notion/oauth/callback")
      token_field(:access_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token])
      lease_fields([:access_token])

      scopes([])

      default_scopes([])

      pkce?(false)
      refresh?(false)
      revoke?(false)
    end
  end

  policies do
    policy :workspace_access do
      label("Workspace access")

      description(
        "Host verifies the actor may use this Notion connection for the requested workspace."
      )

      decision(:allow_operation)
    end
  end
end
