defmodule Jido.Connect.Asana do
  @moduledoc """
  Asana integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Asana:

  - **Personal access token** (`:pat`): Asana personal access token sent via
    the `Authorization: Bearer <token>` header. Created in the Asana developer
    console under "My app settings". Recommended for server-to-server
    integrations, development, and CI.

  - **OAuth2** (`:oauth2`): Standard OAuth2 authorization code flow against the
    Asana authorization server. Grants scoped access on behalf of an Asana user.
    Public integrations use this flow to request access to specific workspaces
    and projects.

  ## Asana Scopes

  The provider declares Asana permission scopes:

  - `default` — basic read access to workspaces, projects, and tasks
  - `read` — extended read access
  - `write` — create and update tasks, projects, and sections
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Asana.Actions.Read,
      Jido.Connect.Asana.Actions.Write
    ]

  defdelegate catalog_packs, to: Jido.Connect.Asana.CatalogPacks, as: :all

  integration do
    id(:asana)
    name("Asana")

    description("Asana work management platform for projects, tasks, and team collaboration.")

    category(:project_management)
    docs(["https://developers.asana.com/reference"])
  end

  catalog do
    package(:jido_connect_asana)
    status(:experimental)
    tags([:work_management, :tasks, :projects, :collaboration])

    capability :api_access do
      kind(:runtime)
      feature(:api_access)
      label("API access")
      description("Asana REST API access via personal access token or OAuth2.")
    end
  end

  auth do
    api_key :pat do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Asana personal access token")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "default",
        "read",
        "write"
      ])

      default_scopes([
        "default",
        "read"
      ])
    end

    oauth2 :oauth2 do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Asana OAuth user")
      authorize_url("https://app.asana.com/-/oauth_authorize")
      token_url("https://app.asana.com/-/oauth_token")
      callback_path("/integrations/asana/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "default",
        "read",
        "write"
      ])

      default_scopes([
        "default",
        "read"
      ])

      optional_scopes([
        "write"
      ])

      pkce?(false)
      refresh?(true)
      revoke?(false)
    end
  end

  policies do
    policy :workspace_access do
      label("Workspace access")

      description(
        "Host verifies the actor may use this Asana connection for the requested workspace."
      )

      decision(:allow_operation)
    end
  end
end
