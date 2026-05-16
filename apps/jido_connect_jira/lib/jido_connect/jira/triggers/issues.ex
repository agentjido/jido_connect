defmodule Jido.Connect.Jira.Triggers.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  triggers do
    webhook :issue_changed do
      id("jira.issue.changed")
      resource(:issue)
      verb(:watch)
      data_classification(:workspace_content)
      label("Issue changed")
      description("Receive Jira webhook notifications for issue created and updated events.")

      verification(%{
        kind: :jira_webhook,
        signature: :hmac_sha256_base64,
        header: "x-hub-signature"
      })

      dedupe(%{key: [:issue_key, :timestamp]})
      handler(Jido.Connect.Jira.Handlers.Triggers.IssueChangedWebhook)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Jira webhook registration ID.")
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:issue_id, :string)
        field(:issue_key, :string)
        field(:project_key, :string)
        field(:summary, :string)
        field(:issue_type_name, :string)
        field(:status_name, :string)
        field(:priority_name, :string)
        field(:labels, {:array, :string})
        field(:assignee_id, :string)
        field(:assignee_name, :string)
        field(:reporter_id, :string)
        field(:reporter_name, :string)
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:changelog, :map)
        field(:webhook_id, :string)
        field(:timestamp, :string)
      end
    end

    webhook :comment_changed do
      id("jira.comment.changed")
      resource(:comment)
      verb(:watch)
      data_classification(:message_content)
      label("Comment changed")
      description("Receive Jira webhook notifications for comment created and updated events.")

      verification(%{
        kind: :jira_webhook,
        signature: :hmac_sha256_base64,
        header: "x-hub-signature"
      })

      dedupe(%{key: [:comment_id, :timestamp]})
      handler(Jido.Connect.Jira.Handlers.Triggers.CommentChangedWebhook)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Jira webhook registration ID.")
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:comment_id, :string)
        field(:comment_body, :string)
        field(:comment_created_at, :string)
        field(:comment_updated_at, :string)
        field(:comment_author_id, :string)
        field(:comment_author_name, :string)
        field(:issue_id, :string)
        field(:issue_key, :string)
        field(:webhook_id, :string)
        field(:timestamp, :string)
      end
    end
  end
end
