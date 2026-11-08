defmodule Jido.Connect.GitHub.Actions.CheckRuns do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_check_runs do
      id "github.check_run.list"
      resource :check_run
      verb :list
      data_classification :workspace_metadata
      label "List check runs"
      description "List check runs for one exact commit SHA."
      handler Jido.Connect.GitHub.Handlers.Actions.ListCheckRuns
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true
        field :sha, :string, required?: true
        field :page, :integer, default: 1
        field :per_page, :integer, default: 100
      end

      output do
        field :check_runs, {:array, :map}
        field :total_count, :integer
        field :page, :map
      end
    end
  end
end
