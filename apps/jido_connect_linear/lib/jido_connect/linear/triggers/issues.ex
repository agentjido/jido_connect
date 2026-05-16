defmodule Jido.Connect.Linear.Triggers.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Linear.ScopeResolver

  triggers do
    webhook :issue_changed do
      id("linear.issue.changed")
      resource(:issue)
      verb(:watch)
      data_classification(:workspace_content)
      label("Issue changed")

      description(
        "Receive Linear webhook notifications for issue created, updated, and removed events."
      )

      verification(%{
        kind: :linear_webhook,
        signature: :hmac_sha256_digest,
        header: "linear-signature"
      })

      dedupe(%{key: [:issue_id, :timestamp]})
      handler(Jido.Connect.Linear.Handlers.Triggers.IssueChangedWebhook)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        scopes(["read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Linear webhook registration ID.")
      end

      signal do
        field(:event_type, :string)
        field(:action, :string)
        field(:issue_id, :string)
        field(:identifier, :string)
        field(:team_id, :string)
        field(:team_key, :string)
        field(:title, :string)
        field(:status_name, :string)
        field(:priority_label, :string)
        field(:assignee_id, :string)
        field(:assignee_name, :string)
        field(:creator_id, :string)
        field(:creator_name, :string)
        field(:labels, {:array, :string})
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:webhook_id, :string)
        field(:timestamp, :string)
      end
    end

    webhook :comment_changed do
      id("linear.comment.changed")
      resource(:comment)
      verb(:watch)
      data_classification(:message_content)
      label("Comment changed")

      description("Receive Linear webhook notifications for comment created and updated events.")

      verification(%{
        kind: :linear_webhook,
        signature: :hmac_sha256_digest,
        header: "linear-signature"
      })

      dedupe(%{key: [:comment_id, :timestamp]})
      handler(Jido.Connect.Linear.Handlers.Triggers.CommentChangedWebhook)

      access do
        auth([:api_key, :oauth2_user], default: :api_key)
        scopes(["read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_id, :string, description: "Linear webhook registration ID.")
      end

      signal do
        field(:event_type, :string)
        field(:action, :string)
        field(:comment_id, :string)
        field(:comment_body, :string)
        field(:issue_id, :string)
        field(:issue_identifier, :string)
        field(:user_id, :string)
        field(:user_name, :string)
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:webhook_id, :string)
        field(:timestamp, :string)
      end
    end
  end
end
