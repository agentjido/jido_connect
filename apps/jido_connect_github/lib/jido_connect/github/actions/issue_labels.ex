defmodule Jido.Connect.GitHub.Actions.IssueLabels do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :add_issue_labels do
      id "github.issue.label.add"
      resource :issue
      verb :update
      data_classification :workspace_content
      label "Add labels to issue"
      description "Add labels to an existing GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.AddIssueLabels
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :labels, {:array, :string}, required?: true
      end

      output do
        field :labels, {:array, :map}
      end
    end

    action :remove_issue_label do
      id "github.issue.label.remove"
      resource :issue
      verb :update
      data_classification :workspace_content
      label "Remove label from issue"
      description "Remove a label from an existing GitHub issue."
      handler Jido.Connect.GitHub.Handlers.Actions.RemoveIssueLabel
      effect :write, confirmation: :required_for_ai

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end

      input do
        field :repo, :string, required?: true, example: "org/repo"
        field :issue_number, :integer, required?: true
        field :label, :string, required?: true, example: "bug"
      end

      output do
        field :labels, {:array, :map}
      end
    end
  end
end
