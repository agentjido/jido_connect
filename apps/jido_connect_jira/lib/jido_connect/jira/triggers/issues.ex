defmodule Jido.Connect.Jira.Triggers.Issues do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  @matched_webhook_ids "IDs of the webhooks the delivery matched, from matchedWebhookIds. " <>
                         "Administrator webhooks do not send them, so the field is absent; " <>
                         "the per-delivery identifier is the delivery_id of verify_delivery/4."

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
        signature: :hmac_sha256,
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

        field(:issue_event_type_name, :string,
          description:
            "Jira's issue_event_type_name, unchanged. It names the Jira event that fired, " <>
              "which depends on the operation and on the workflow transition; read status, " <>
              "assignee and due-date changes from changelog items."
        )

        field(:actor_id, :string, description: "Account ID of the top-level user.")
        field(:actor_name, :string, description: "Display name of the top-level user.")
        field(:issue_id, :string)
        field(:issue_key, :string)
        field(:project_key, :string)
        field(:project_name, :string)
        field(:summary, :string)
        field(:issue_type_name, :string)
        field(:status_name, :string)
        field(:priority_name, :string)
        field(:labels, {:array, :string})

        field(:assigned, :boolean,
          description:
            "true when fields.assignee holds a user, false when Jira sends it as null; " <>
              "absent when the fields leave the assignee out."
        )

        field(:assignee_id, :string)
        field(:assignee_name, :string)
        field(:reporter_id, :string)
        field(:reporter_name, :string)
        field(:created_at, :string)
        field(:updated_at, :string)

        field(:changelog, :map,
          description:
            "Changelog id and items with field, field_id, field_type and the from, " <>
              "from_string, to and to_string keys Jira sent, null values included."
        )

        field(:matched_webhook_ids, {:array, :string}, description: @matched_webhook_ids)
        field(:timestamp, :string, description: "Delivery time in ISO 8601.")
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
        signature: :hmac_sha256,
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

        field(:actor_id, :string,
          description:
            "Account ID of comment.author for comment_created and of " <>
              "comment.updateAuthor for comment_updated."
        )

        field(:actor_name, :string, description: "Display name of the same user as actor_id.")

        field(:comment_id, :string)
        field(:comment_body, :string)
        field(:comment_body_unsupported_nodes, {:array, :string})
        field(:comment_created_at, :string)
        field(:comment_updated_at, :string)
        field(:comment_author_id, :string)
        field(:comment_author_name, :string)
        field(:issue_id, :string)
        field(:issue_key, :string)
        field(:matched_webhook_ids, {:array, :string}, description: @matched_webhook_ids)
        field(:timestamp, :string, description: "Delivery time in ISO 8601.")
      end
    end
  end
end
