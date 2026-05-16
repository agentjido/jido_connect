defmodule Jido.Connect.Linear.Actions.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Linear.ScopeResolver

  actions do
    action :get_issue do
      id("linear.issue.get")
      resource(:issue)
      verb(:get)
      data_classification(:workspace_content)
      label("Get issue")
      description("Fetch a Linear issue by ID.")
      handler(Jido.Connect.Linear.Handlers.Actions.GetIssue)
      effect(:read)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:issue_id, :string, required?: true, example: "LIN-123")

        field(:fields, {:array, :string},
          default: nil,
          description: "List of GraphQL fields to return. Defaults to standard fields."
        )
      end

      output do
        field(:id, :string)
        field(:identifier, :string)
        field(:title, :string)
        field(:description, :string)
        field(:status, :map)
        field(:priority, :map)
        field(:team, :map)
        field(:assignee, :map)
        field(:labels, {:array, :map})
        field(:created_at, :string)
        field(:updated_at, :string)
      end
    end

    action :search_issues do
      id("linear.issue.search")
      resource(:issue)
      verb(:search)
      data_classification(:workspace_content)
      label("Search issues")
      description("Search Linear issues using a filter.")
      handler(Jido.Connect.Linear.Handlers.Actions.SearchIssues)
      effect(:read)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:filter, :map,
          default: nil,
          description: "Linear issue filter object."
        )

        field(:first, :integer, default: 50)
        field(:after, :string, default: nil)
        field(:order_by, :string, default: "updatedAt")
      end

      output do
        field(:issues, {:array, :map})
        field(:has_next_page, :boolean)
        field(:end_cursor, :string)
        field(:total_count, :integer)
      end
    end

    action :create_issue do
      id("linear.issue.create")
      resource(:issue)
      verb(:create)
      data_classification(:workspace_content)
      label("Create issue")
      description("Create a new Linear issue.")
      handler(Jido.Connect.Linear.Handlers.Actions.CreateIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["write", "issues:create"], resolver: @scope_resolver)
      end

      input do
        field(:team_id, :string, required?: true)
        field(:title, :string, required?: true)
        field(:description, :string)
        field(:priority, :string)
        field(:assignee_id, :string)
        field(:labels, {:array, :string}, default: [])
      end

      output do
        field(:id, :string)
        field(:identifier, :string)
        field(:title, :string)
      end
    end

    action :update_issue do
      id("linear.issue.update")
      resource(:issue)
      verb(:update)
      data_classification(:workspace_content)
      label("Update issue")
      description("Update fields on an existing Linear issue.")
      handler(Jido.Connect.Linear.Handlers.Actions.UpdateIssue)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["write"], resolver: @scope_resolver)
      end

      input do
        field(:issue_id, :string, required?: true, example: "LIN-123")
        field(:title, :string)
        field(:description, :string)
        field(:priority, :string)
        field(:status, :string)
        field(:assignee_id, :string)
        field(:labels, {:array, :string})
      end

      output do
        field(:updated, :boolean)
      end
    end

    action :add_comment do
      id("linear.issue.comment.create")
      resource(:comment)
      verb(:create)
      data_classification(:message_content)
      label("Add comment")
      description("Add a comment to a Linear issue.")
      handler(Jido.Connect.Linear.Handlers.Actions.AddComment)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["write", "comments:create"], resolver: @scope_resolver)
      end

      input do
        field(:issue_id, :string, required?: true, example: "LIN-123")
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
