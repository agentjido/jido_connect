defmodule Jido.Connect.Jira.Actions.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  actions do
    action :get_issue do
      id("jira.issue.get")
      resource(:issue)
      verb(:get)
      data_classification(:workspace_content)
      label("Get issue")
      description("Fetch a Jira issue by key.")
      handler(Jido.Connect.Jira.Handlers.Actions.GetIssue)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string, required?: true, example: "PROJ-123")
      end

      output do
        field(:key, :string)
        field(:summary, :string)
        field(:status, :map)
        field(:project, :map)
      end
    end

    action :list_issues do
      id("jira.issue.search")
      resource(:issue)
      verb(:search)
      data_classification(:workspace_content)
      label("Search issues")
      description("Search Jira issues using JQL.")
      handler(Jido.Connect.Jira.Handlers.Actions.SearchIssues)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:jql, :string, required?: true, example: "project = PROJ ORDER BY updated DESC")
        field(:max_results, :integer, default: 50)
        field(:start_at, :integer, default: 0)
      end

      output do
        field(:issues, {:array, :map})
        field(:total, :integer)
      end
    end

    action :create_issue do
      id("jira.issue.create")
      resource(:issue)
      verb(:create)
      data_classification(:workspace_content)
      label("Create issue")
      description("Create a new Jira issue.")
      handler(Jido.Connect.Jira.Handlers.Actions.CreateIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:project_key, :string, required?: true, example: "PROJ")
        field(:issue_type, :string, required?: true, default: "Task")
        field(:summary, :string, required?: true)
        field(:description, :string)
        field(:labels, {:array, :string}, default: [])
        field(:priority, :string)
        field(:assignee_account_id, :string)
      end

      output do
        field(:key, :string)
        field(:id, :string)
        field(:url, :string)
      end
    end
  end
end
