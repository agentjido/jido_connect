defmodule Jido.Connect.GitHub.Actions.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_issues do
      id "github.issue.list"
      resource :issue
      verb :list
      data_classification :workspace_content
      label "List issues"
      description "List issues in a GitHub repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListIssues
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :state, :string, enum: ["open", "closed", "all"], default: "open"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 100
      end

      output do
        field :issues, {:array, :map}
        field :page, :map
      end
    end

    action :create_issue do
      id "github.issue.create"
      resource :issue
      verb :create
      data_classification :workspace_content
      label "Create issue"
      description "Create a GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.CreateIssue
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :title, :string, required?: true
        field :body, :string
        field :labels, {:array, :string}, default: []
      end

      output do
        field :number, :integer
        field :url, :string
        field :title, :string
        field :state, :string
      end
    end
  end
end
