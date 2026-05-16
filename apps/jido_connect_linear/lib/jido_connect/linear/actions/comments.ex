defmodule Jido.Connect.Linear.Actions.Comments do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Linear.ScopeResolver

  actions do
    action :list_comments do
      id("linear.issue.comments.list")
      resource(:comment)
      verb(:list)
      data_classification(:workspace_content)
      label("List comments")
      description("List comments on a Linear issue with pagination.")
      handler(Jido.Connect.Linear.Handlers.Actions.ListComments)
      effect(:read)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        policies([:team_access])
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:issue_id, :string, required?: true, example: "uuid-001")

        field(:first, :integer,
          default: 50,
          description: "Maximum number of comments to return per page."
        )

        field(:after, :string,
          default: nil,
          description: "Cursor for pagination; pass end_cursor from a previous page."
        )
      end

      output do
        field(:comments, {:array, :map})
        field(:has_next_page, :boolean)
        field(:end_cursor, :string)
        field(:total_count, :integer)
      end
    end
  end
end
