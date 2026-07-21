defmodule Jido.Connect.Zendesk.Triggers.Tickets do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Zendesk.ScopeResolver

  triggers do
    webhook :ticket_changed do
      id("zendesk.ticket.changed")
      resource(:ticket)
      verb(:watch)
      data_classification(:workspace_content)
      label("Ticket changed")

      description(
        "Receive Zendesk webhook notifications for ticket created, updated, and status changed events."
      )

      verification(%{
        kind: :zendesk_webhook,
        signature: :hmac_sha256_base64,
        header: "x-zendesk-webhook-signature"
      })

      dedupe(%{key: [:ticket_id, :timestamp]})
      handler(Jido.Connect.Zendesk.Handlers.Triggers.TicketChangedWebhook)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Zendesk webhook shared secret for signature verification."
        )
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:ticket_id, :integer)
        field(:subject, :string)
        field(:status, :string)
        field(:priority, :string)
        field(:type, :string)
        field(:group_id, :integer)
        field(:assignee_id, :integer)
        field(:requester_id, :integer)
        field(:organization_id, :integer)
        field(:tags, {:array, :string})
        field(:created_at, :string)
        field(:updated_at, :string)
        field(:via, :map)
        field(:previous, :map)
        field(:webhook_id, :string)
        field(:account_id, :string)
        field(:timestamp, :string)
      end
    end

    webhook :comment_changed do
      id("zendesk.ticket.comment.changed")
      resource(:comment)
      verb(:watch)
      data_classification(:workspace_content)
      label("Comment changed")

      description("Receive Zendesk webhook notifications for comment created events on tickets.")

      verification(%{
        kind: :zendesk_webhook,
        signature: :hmac_sha256_base64,
        header: "x-zendesk-webhook-signature"
      })

      dedupe(%{key: [:comment_id, :timestamp]})
      handler(Jido.Connect.Zendesk.Handlers.Triggers.CommentChangedWebhook)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Zendesk webhook shared secret for signature verification."
        )
      end

      signal do
        field(:event_type, :string)
        field(:change_type, :string)
        field(:comment_id, :integer)
        field(:comment_body, :string)
        field(:comment_html_body, :string)
        field(:comment_public, :boolean)
        field(:comment_author_id, :integer)
        field(:ticket_id, :integer)
        field(:ticket_subject, :string)
        field(:webhook_id, :string)
        field(:account_id, :string)
        field(:timestamp, :string)
      end
    end
  end
end
