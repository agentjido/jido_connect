defmodule Jido.Connect.GitLab do
  @moduledoc """
  GitLab integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for GitLab:

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
    against the GitLab instance authorization server. Grants scoped access
    on behalf of a GitLab user.

  - **PAT** (`:pat`): GitLab personal access token used as a Bearer token.
    Recommended for server-to-server integrations, development, and CI.

  ## GitLab Scopes

  The provider declares GitLab API scopes:

  - `api` / `read_api`
  - `read_repository` / `write_repository`
  - `read_api` (default read-only scope)
  """

  use Jido.Connect,
    fragments: []

  integration do
    id :gitlab
    name "GitLab"
    description "GitLab project, issue, merge request, pipeline, and repository tools."
    category :developer_tools
    docs ["https://docs.gitlab.com/ee/api/rest/"]
  end

  catalog do
    package :jido_connect_gitlab
    status :experimental
    tags [:source_control, :issues, :developer_tools, :ci_cd]

    capability :webhook_verification do
      kind :webhook
      feature :webhook_verification
      label "Webhook verification"
      description "Secret-token verification and GitLab webhook normalization."
    end
  end

  auth do
    oauth2 :oauth2_user do
      default? true
      owner :app_user
      subject :user
      label "GitLab OAuth user"
      authorize_url "https://gitlab.com/oauth/authorize"
      token_url "https://gitlab.com/oauth/token"
      callback_path "/integrations/gitlab/oauth/callback"
      token_field :access_token
      refresh_token_field :refresh_token
      setup :oauth2_authorization_code
      credential_fields [:access_token, :refresh_token]
      lease_fields [:access_token]

      scopes [
        "api",
        "read_api",
        "read_repository",
        "write_repository"
      ]

      default_scopes ["read_api"]
      optional_scopes ["api", "read_repository", "write_repository"]

      pkce? true
      refresh? true
      revoke? true
    end

    api_key :pat do
      default? false
      owner :app_user
      subject :user
      label "GitLab personal access token"
      setup :api_key_bearer_token
      credential_fields [:api_key]
      lease_fields [:api_key]

      scopes [
        "api",
        "read_api",
        "read_repository",
        "write_repository"
      ]

      default_scopes [
        "read_api",
        "read_repository"
      ]
    end
  end

  policies do
    policy :project_access do
      label "Project access"

      description "Host verifies the actor may use this GitLab connection for the requested project."

      subject {:input, :project_path}
      owner {:connection, :owner}
      decision :allow_operation
    end
  end
end
