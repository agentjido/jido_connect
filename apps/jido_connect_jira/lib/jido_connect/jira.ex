defmodule Jido.Connect.Jira do
  @moduledoc """
  Jira integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Atlassian Cloud:

  - **API token** (`:api_token`): Jira personal access token or Atlassian
    API token used as a Bearer token. Recommended for server-to-server
    integrations, development, and CI.

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
    with PKCE against the Atlassian authorization server. Grants scoped
    access on behalf of an Atlassian user.

  ## Atlassian Cloud Scopes

  The provider declares Atlassian Cloud scopes for Jira:

  - `read:jira-work` / `write:jira-work`
  - `read:jira-users` / `read:jira-configuration`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Jira.Actions.Issues
    ]

  integration do
    id(:jira)
    name("Jira")

    description(
      "Jira issue tracking, project management, and workflow tools for Atlassian Cloud."
    )

    category(:project_management)
    docs(["https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/"])
  end

  catalog do
    package(:jido_connect_jira)
    status(:experimental)
    tags([:project_management, :issues, :work_management])

    capability :webhook_verification do
      kind(:webhook)
      feature(:webhook_verification)
      label("Webhook verification")
      description("Signature verification and Jira webhook normalization.")
    end
  end

  auth do
    api_key :api_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Jira API token")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "read:jira-work",
        "write:jira-work",
        "read:jira-users",
        "read:jira-configuration"
      ])

      default_scopes([
        "read:jira-work",
        "read:jira-users",
        "read:jira-configuration"
      ])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Jira OAuth user")
      authorize_url("https://auth.atlassian.com/authorize")
      token_url("https://auth.atlassian.com/oauth/token")
      callback_path("/integrations/jira/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "read:jira-work",
        "write:jira-work",
        "read:jira-users",
        "read:jira-configuration"
      ])

      default_scopes([
        "read:jira-work",
        "read:jira-users",
        "read:jira-configuration"
      ])

      optional_scopes([
        "write:jira-work"
      ])

      pkce?(true)
      refresh?(true)
      revoke?(false)
    end
  end

  policies do
    policy :project_access do
      label("Project access")

      description(
        "Host verifies the actor may use this Jira connection for the requested project."
      )

      subject({:input, :project_key})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
