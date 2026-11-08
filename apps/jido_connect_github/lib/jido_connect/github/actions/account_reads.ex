defmodule Jido.Connect.GitHub.Actions.AccountReads do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :get_user do
      id "github.user.get"
      resource :user
      verb :get
      data_classification :identity
      label "Get authenticated user"
      description "Fetch the identity for the current GitHub user access token."
      handler Jido.Connect.GitHub.Handlers.Actions.GetUser
      effect :read

      access do
        auth [:user], default: :user
        scopes ["read:user"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      output do
        field :user, :map
      end
    end

    action :list_user_installations do
      id "github.user_installation.list"
      resource :installation
      verb :list
      data_classification :workspace_metadata
      label "List user installations"
      description "List GitHub App installations available to the current user token."
      handler Jido.Connect.GitHub.Handlers.Actions.ListUserInstallations
      effect :read

      access do
        auth [:user], default: :user
        scopes [], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :page, :integer, default: 1
        field :per_page, :integer, default: 100
      end

      output do
        field :installations, {:array, :map}
        field :total_count, :integer
        field :page, :map
      end
    end

    action :list_user_installation_repositories do
      id "github.user_installation_repository.list"
      resource :repository
      verb :list
      data_classification :workspace_metadata
      label "List user installation repositories"

      description "List repositories granted to one GitHub App installation for a user token."

      handler Jido.Connect.GitHub.Handlers.Actions.ListUserInstallationRepositories
      effect :read

      access do
        auth [:user], default: :user
        scopes ["metadata:read"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :installation_id, :integer, required?: true
        field :page, :integer, default: 1
        field :per_page, :integer, default: 100
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
        field :page, :map
      end
    end

    action :get_rate_limit do
      id "github.rate_limit.get"
      resource :rate_limit
      verb :get
      data_classification :workspace_metadata
      label "Get rate limit"
      description "Fetch the current GitHub API rate state."
      handler Jido.Connect.GitHub.Handlers.Actions.GetRateLimit
      effect :read

      access do
        auth [:user, :installation], default: :user
        scopes [], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      output do
        field :resources, :map
      end
    end
  end
end
