defmodule Jido.Connect.GitHub.Actions.PullRequests do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_pull_requests do
      id "github.pull_request.list"
      resource :pull_request
      verb :list
      data_classification :workspace_content
      label "List pull requests"
      description "List pull requests in a GitHub repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListPullRequests
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :state, :string, enum: ["open", "closed", "all"], default: "open"
        field :head, :string
        field :base, :string

        field :sort, :string,
          enum: ["created", "updated", "popularity", "long-running"],
          default: "created"

        field :direction, :string, enum: ["asc", "desc"], default: "desc"
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :pull_requests, {:array, :map}
        field :page, :map
      end
    end
  end
end
