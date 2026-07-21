defmodule Jido.Connect.Linear do
  @moduledoc """
  Linear integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles:

  - **API key** (`:api_key`): Linear personal access token used as a Bearer
    token. Recommended for server-to-server integrations, development, and CI.

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
    against the Linear authorization server. Grants scoped access on behalf of
    a Linear user.

  ## Linear Scopes

  The provider declares Linear scopes:

  - `read` / `write`
  - `issues:create` / `comments:create`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Linear.Actions.Issues,
      Jido.Connect.Linear.Actions.Comments,
      Jido.Connect.Linear.Actions.Teams,
      Jido.Connect.Linear.Triggers.Issues
    ]

  defdelegate catalog_packs, to: Jido.Connect.Linear.CatalogPacks, as: :all

  integration do
    id(:linear)
    name("Linear")

    description("Linear issue tracking and project management with GraphQL API.")

    category(:project_management)
    docs(["https://developers.linear.app/docs"])
  end

  catalog do
    package(:jido_connect_linear)
    status(:experimental)
    tags([:project_management, :issues, :work_management])

    capability :webhook_verification do
      kind(:webhook)
      feature(:webhook_verification)
      label("Webhook verification")
      description("Signature verification and Linear webhook normalization.")
    end
  end

  auth do
    api_key :api_key do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Linear API key")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "read",
        "write",
        "issues:create",
        "comments:create"
      ])

      default_scopes([
        "read"
      ])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Linear OAuth user")
      authorize_url("https://linear.app/oauth/authorize")
      token_url("https://api.linear.app/oauth/token")
      callback_path("/integrations/linear/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "read",
        "write",
        "issues:create",
        "comments:create"
      ])

      default_scopes([
        "read"
      ])

      optional_scopes([
        "write",
        "issues:create",
        "comments:create"
      ])

      pkce?(true)
      refresh?(true)
      revoke?(false)
    end
  end

  policies do
    policy :team_access do
      label("Team access")

      description(
        "Host verifies the actor may use this Linear connection for the requested team."
      )

      subject({:input, :team_id})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
