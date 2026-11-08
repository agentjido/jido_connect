defmodule Jido.Connect.GitHub.Actions.PullRequestEvidence do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_pull_request_reviews do
      id "github.pull_request_review.list"
      resource :pull_request_review
      verb :list
      data_classification :workspace_content
      label "List pull request reviews"
      description "List reviews for one pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.ListPullRequestReviews
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :pull_number, :integer, required?: true
        field :page, :integer, default: 1
        field :per_page, :integer, default: 100
      end

      output do
        field :reviews, {:array, :map}
        field :page, :map
      end
    end

    action :list_pull_request_requested_reviewers do
      id "github.pull_request_requested_reviewer.list"
      resource :pull_request_reviewer
      verb :list
      data_classification :workspace_metadata
      label "List requested reviewers"
      description "List users and teams requested to review one pull request."
      handler Jido.Connect.GitHub.Handlers.Actions.ListPullRequestRequestedReviewers
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :pull_number, :integer, required?: true
      end

      output do
        field :users, {:array, :map}
        field :teams, {:array, :map}
      end
    end
  end
end
