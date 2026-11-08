defmodule Jido.Connect.GitHub.Actions.WorkflowRuns do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_workflow_runs do
      id "github.workflow_run.list"
      resource :workflow_run
      verb :list
      data_classification :workspace_metadata
      label "List workflow runs"
      description "List GitHub Actions workflow runs in a repository."
      handler Jido.Connect.GitHub.Handlers.Actions.ListWorkflowRuns
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :workflow, :string
        field :branch, :string
        field :status, :string
        field :event, :string
        field :page, :integer, default: 1
        field :per_page, :integer, default: 30
      end

      output do
        field :workflow_runs, {:array, :map}
        field :total_count, :integer
        field :page, :map
      end
    end
  end
end
