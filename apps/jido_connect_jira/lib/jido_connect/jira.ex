defmodule Jido.Connect.Jira do
  @moduledoc """
  Jira integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles for Atlassian Cloud:

  - **API token** (`:api_token`): Atlassian account email and API token sent
    with HTTP Basic authentication.

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow
    with PKCE against the Atlassian authorization server. Grants scoped
    access on behalf of an Atlassian user.

  ## Atlassian Cloud Scopes

  The provider declares Atlassian Cloud scopes for Jira:

  - `read:jira-work` / `write:jira-work`
  - `read:jira-users` / `read:jira-configuration`

  ## Issue Reads

  `jira.issue.get` accepts an issue key or a numeric issue ID and returns the
  issue's `id`, `url` (the API `self` URL), project, assignee, status, the
  plain-text `description` with `description_unsupported_nodes` and the
  date-only `due_date`. Fields that Jira returns as `null` are absent from the
  output; `missing_fields` lists the requested Jira field keys that the
  response does not contain at all. The selectors `*all` and `*navigable`
  count only the issue fields the connector reads; custom fields behind them
  and other `*` selectors are not checked.

  ## Issue Search

  `jira.issue.search` uses Jira's enhanced JQL search,
  `POST /rest/api/3/search/jql`, because Atlassian removed
  `POST /rest/api/3/search`. Each call returns one page: pass the page's
  `next_page_token` to the next call until `is_last` is `true`. A page can be
  empty while `is_last` is `false`.

  Deprecated for one release and removed in the next: the input `start_at`
  accepts only `0`, and the outputs `total` and `start_at` are declared but
  never returned, because enhanced search has neither offsets nor a total.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Jira.Actions.Issues,
      Jido.Connect.Jira.Actions.Projects,
      Jido.Connect.Jira.Actions.Metadata,
      Jido.Connect.Jira.Actions.Boards,
      Jido.Connect.Jira.Actions.Filters,
      Jido.Connect.Jira.Actions.Plans,
      Jido.Connect.Jira.Triggers.Issues
    ]

  defdelegate catalog_packs, to: Jido.Connect.Jira.CatalogPacks, as: :all

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
      setup :api_token_basic_auth
      credential_fields([:email, :api_token])
      lease_fields([:email, :api_token])

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

    policy :jira_admin_access do
      label("Jira administration access")

      description(
        "Host verifies that the actor can use Jira plan operations that require Administer Jira."
      )

      subject({:context, :actor})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
