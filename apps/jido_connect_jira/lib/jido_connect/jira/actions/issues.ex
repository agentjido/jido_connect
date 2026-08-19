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

        field(:fields, {:array, :string},
          default: nil,
          description: "Comma-separated or list of field keys to return. Defaults to all fields."
        )
      end

      output do
        field(:key, :string)
        field(:summary, :string)
        field(:status, :map)
        field(:project, :map)
        field(:assignee, :map)
        field(:priority, :map)
        field(:labels, {:array, :string})
        field(:created_at, :string)
        field(:updated_at, :string)
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

        field(:fields, {:array, :string},
          default: ["summary", "status", "assignee", "updated"],
          description: "List of field keys to return in each issue."
        )
      end

      output do
        field(:issues, {:array, :map})
        field(:total, :integer)
        field(:start_at, :integer)
        field(:max_results, :integer)
        field(:is_last, :boolean)
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
      preview(Jido.Connect.Jira.Previews.CreateIssue)
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

    action :update_issue do
      id("jira.issue.update")
      resource(:issue)
      verb(:update)
      data_classification(:workspace_content)
      label("Update issue")
      description("Update fields on an existing Jira issue.")
      handler(Jido.Connect.Jira.Handlers.Actions.UpdateIssue)
      preview(Jido.Connect.Jira.Previews.UpdateIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string, required?: true, example: "PROJ-123")
        field(:summary, :string)
        field(:description, :string)
        field(:priority, :string)
        field(:labels, {:array, :string})
        field(:assignee_account_id, :string)
      end

      output do
        field(:updated, :boolean)
      end
    end

    action :transition_issue do
      id("jira.issue.transition")
      resource(:issue)
      verb(:update)
      data_classification(:workspace_content)
      label("Transition issue")
      description("Transition a Jira issue to a new workflow status.")
      handler(Jido.Connect.Jira.Handlers.Actions.TransitionIssue)
      preview(Jido.Connect.Jira.Previews.TransitionIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string, required?: true, example: "PROJ-123")
        field(:transition_id, :string, required?: true, example: "21")
        field(:fields, :map, default: nil)
      end

      output do
        field(:transitioned, :boolean)
      end
    end

    action :assign_issue do
      id("jira.issue.assign")
      resource(:issue)
      verb(:update)
      data_classification(:workspace_content)
      label("Assign issue")
      description("Assign a Jira issue to a user by account ID.")
      handler(Jido.Connect.Jira.Handlers.Actions.AssignIssue)
      preview(Jido.Connect.Jira.Previews.AssignIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string, required?: true, example: "PROJ-123")
        field(:account_id, :string, required?: true, example: "5f8a7b9c1d2e3f4a5b6c7d8e")
      end

      output do
        field(:assigned, :boolean)
      end
    end

    action :add_comment do
      id("jira.issue.comment.create")
      resource(:comment)
      verb(:create)
      data_classification(:message_content)
      label("Add comment")
      description("Add a comment to a Jira issue.")
      handler(Jido.Connect.Jira.Handlers.Actions.AddComment)
      preview(Jido.Connect.Jira.Previews.AddComment)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["write:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string, required?: true, example: "PROJ-123")
        field(:body, :string, required?: true)
      end

      output do
        field(:id, :string)
        field(:body, :string)
        field(:created_at, :string)
      end
    end
  end
end
