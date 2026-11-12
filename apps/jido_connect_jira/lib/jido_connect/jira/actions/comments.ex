defmodule Jido.Connect.Jira.Actions.Comments do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  actions do
    action :list_comments do
      id("jira.issue.comment.list")
      resource(:comment)
      verb(:list)
      data_classification(:message_content)
      label("List comments")

      description(
        "List one page of a Jira issue's comments, oldest first. " <>
          "Continue with next_start_at until is_last is true."
      )

      handler(Jido.Connect.Jira.Handlers.Actions.ListComments)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        policies([:project_access])
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      input do
        field(:issue_key, :string,
          required?: true,
          example: "PROJ-123",
          description: "Issue key, such as PROJ-123, or numeric issue ID, such as 10001."
        )

        field(:start_at, :integer,
          default: 0,
          minimum: 0,
          description: "Offset of the first comment, from next_start_at of the previous page."
        )

        field(:max_results, :integer,
          default: 50,
          minimum: 1,
          maximum: 100,
          description:
            "Page size, 1 to 100. Jira can return fewer comments; is_last marks the end."
        )
      end

      output do
        field(:issue, :string, description: "The issue key or ID as supplied.")

        field(:comments, {:array, :map},
          description:
            "Comments of this page, oldest first, each with id, url, plain-text body, " <>
              "body_unsupported_nodes, the original ADF body_adf, author, update_author, " <>
              "created_at, updated_at and, for a restricted comment, visibility. " <>
              "A comment without a body has no body fields; an empty body is \"\"."
        )

        field(:start_at, :integer, description: "Offset of the first comment of this page.")
        field(:max_results, :integer, description: "Page size that Jira applied.")
        field(:total, :integer, description: "Number of comments that the caller can see.")

        field(:is_last, :boolean,
          description: "True when start_at plus the comments of this page reaches total."
        )

        field(:next_start_at, :integer,
          description:
            "start_at for the next page: start_at plus the comments of this page. " <>
              "Absent on the last page."
        )
      end
    end
  end
end
