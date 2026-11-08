defmodule Jido.Connect.GitHub.Actions.GitObjects do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :get_commit do
      id "github.commit.get"
      resource :commit
      verb :get
      data_classification :workspace_content
      label "Get commit"
      description "Fetch one commit by branch, tag, or SHA."
      handler Jido.Connect.GitHub.Handlers.Actions.GetCommit
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :ref, :string, required?: true
      end

      output do
        field :commit, :map
      end
    end

    action :get_git_tree do
      id "github.git_tree.get"
      resource :git_tree
      verb :get
      data_classification :workspace_content
      label "Get Git tree"
      description "Fetch one Git tree with optional recursive expansion."
      handler Jido.Connect.GitHub.Handlers.Actions.GetGitTree
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :sha, :string, required?: true
        field :recursive, :boolean, default: false
      end

      output do
        field :sha, :string
        field :entries, {:array, :map}
        field :truncated, :boolean
      end
    end

    action :get_git_blob do
      id "github.git_blob.get"
      resource :git_blob
      verb :get
      data_classification :workspace_content
      label "Get Git blob"
      description "Fetch one Git blob with its reported size and encoding."
      handler Jido.Connect.GitHub.Handlers.Actions.GetGitBlob
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :sha, :string, required?: true
      end

      output do
        field :sha, :string
        field :encoding, :string
        field :size, :integer
        field :content, :string
      end
    end
  end
end
