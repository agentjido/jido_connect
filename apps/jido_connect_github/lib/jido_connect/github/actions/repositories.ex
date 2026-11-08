defmodule Jido.Connect.GitHub.Actions.Repositories do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_repositories do
      id "github.repo.list"
      resource :repository
      verb :list
      data_classification :workspace_metadata
      label "List repositories"
      description "List GitHub repositories visible to the connection."
      handler Jido.Connect.GitHub.Handlers.Actions.ListRepositories
      effect :read

      access do
        auth [:user, :installation], default: :user
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
      end
    end

    action :search_repositories do
      id "github.repo.search"
      resource :repository
      verb :search
      data_classification :workspace_metadata
      label "Search repositories"
      description "Search GitHub repositories with query helpers and pagination."
      handler Jido.Connect.GitHub.Handlers.Actions.SearchRepositories
      effect :read

      access do
        auth [:user, :installation], default: :user
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :query, :string, required?: true, example: "jido"
        field :user, :string, example: "octocat"
        field :org, :string, example: "github"
        field :language, :string, example: "elixir"
        field :topic, :string, example: "agent"
        field :visibility, :string, default: "all"
        field :archived, :boolean
        field :fork, :boolean
        field :sort, :string, default: "updated"
        field :direction, :string, default: "desc"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
      end
    end

    action :list_installation_repositories do
      id "github.installation_repository.list"
      resource :repository
      verb :list
      data_classification :workspace_metadata
      label "List installation repositories"

      description "List repositories accessible to a GitHub App installation and its granted permissions."

      handler Jido.Connect.GitHub.Handlers.Actions.ListInstallationRepositories
      effect :read

      access do
        auth [:installation], default: :installation
        scopes ["metadata:read"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :repositories, {:array, :map}
        field :total_count, :integer
        field :permissions, :map
      end
    end

    action :get_repository do
      id "github.repo.get"
      resource :repository
      verb :get
      data_classification :workspace_metadata
      label "Get repository"
      description "Fetch GitHub repository metadata by owner and name."
      handler Jido.Connect.GitHub.Handlers.Actions.GetRepository
      effect :read

      access do
        auth [:user, :installation], default: :user
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :owner, :string, required?: true, example: "org"
        field :name, :string, required?: true, example: "repo"
      end

      output do
        field :id, :integer
        field :name, :string
        field :full_name, :string
        field :owner, :map
        field :private, :boolean
        field :visibility, :string
        field :default_branch, :string
        field :permissions, :map
        field :url, :string
        field :archived, :boolean
        field :fork, :boolean
        field :updated_at, :string
      end
    end

    action :list_branches do
      id "github.branch.list"
      resource :branch
      verb :list
      data_classification :workspace_metadata
      label "List branches"
      description "List GitHub repository branches with pagination."
      handler Jido.Connect.GitHub.Handlers.Actions.ListBranches
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :branches, {:array, :map}
      end
    end

    action :create_branch do
      id "github.branch.create"
      resource :branch
      verb :create
      data_classification :workspace_metadata
      label "Create branch"
      description "Create a GitHub repository branch from an existing ref or commit SHA."
      handler Jido.Connect.GitHub.Handlers.Actions.CreateBranch
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :branch, :string, required?: true, example: "feature/example"
        field :source_ref, :string, example: "main"
        field :source_sha, :string, example: "abc123"
      end

      output do
        field :repo, :string
        field :branch, :string
        field :ref, :string
        field :sha, :string
        field :url, :string
        field :object, :map
      end
    end

    action :list_commits do
      id "github.commit.list"
      resource :commit
      verb :list
      data_classification :workspace_content
      label "List commits"
      description "List GitHub repository commits for an optional ref and path with pagination."
      handler Jido.Connect.GitHub.Handlers.Actions.ListCommits
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :ref, :string, example: "main"
        field :path, :string, example: "lib/example.ex"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :commits, {:array, :map}
      end
    end

    action :compare_refs do
      id "github.ref.compare"
      resource :ref
      verb :get
      data_classification :workspace_content
      label "Compare refs"
      description "Compare two GitHub repository refs and return status, commits, and file stats."
      handler Jido.Connect.GitHub.Handlers.Actions.CompareRefs
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :base, :string, required?: true, example: "main"
        field :head, :string, required?: true, example: "feature/ref"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :status, :string
        field :ahead_by, :integer
        field :behind_by, :integer
        field :total_commits, :integer
        field :commits, {:array, :map}
        field :files, {:array, :map}
      end
    end

    action :read_file do
      id "github.file.read"
      resource :file
      verb :read
      data_classification :workspace_content
      label "Read file contents"
      description "Read a GitHub repository file by path and optional ref."
      handler Jido.Connect.GitHub.Handlers.Actions.ReadFile
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :path, :string, required?: true, example: "README.md"
        field :ref, :string
      end

      output do
        field :repo, :string
        field :path, :string
        field :name, :string
        field :sha, :string
        field :size, :integer
        field :type, :string
        field :encoding, :string
        field :binary, :boolean
        field :content, :string
        field :content_base64, :string
        field :url, :string
        field :html_url, :string
        field :download_url, :string
      end
    end

    action :update_file do
      id "github.file.update"
      resource :file
      verb :update
      data_classification :workspace_content
      label "Create or update file contents"
      description "Create or update a GitHub repository file by path."
      handler Jido.Connect.GitHub.Handlers.Actions.UpdateFile
      effect :write, confirmation: :always

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :path, :string, required?: true, example: "README.md"
        field :content, :string, required?: true
        field :message, :string, required?: true
        field :branch, :string
        field :sha, :string
        field :committer, :map
      end

      output do
        field :repo, :string
        field :path, :string
        field :sha, :string
        field :url, :string
        field :html_url, :string
        field :download_url, :string
        field :commit_sha, :string
        field :commit_message, :string
      end
    end
  end
end
