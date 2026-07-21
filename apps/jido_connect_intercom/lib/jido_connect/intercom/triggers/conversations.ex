defmodule Jido.Connect.Intercom.Triggers.Conversations do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Intercom.ScopeResolver

  triggers do
    webhook :conversation_created do
      id("intercom.conversation.user.created")
      resource(:conversation)
      verb(:watch)
      data_classification(:workspace_content)
      label("Conversation created")

      description(
        "Receive Intercom webhook notifications when a user creates a new conversation."
      )

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ConversationCreatedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:conversation_id, :string)
        field(:conversation_state, :string)
        field(:conversation_title, :string)
        field(:conversation_body, :string)
        field(:conversation_delivered_as, :string)
        field(:author_id, :string)
        field(:author_type, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :admin_replied do
      id("intercom.conversation.admin.replied")
      resource(:conversation)
      verb(:watch)
      data_classification(:workspace_content)
      label("Admin replied")

      description(
        "Receive Intercom webhook notifications when an admin replies to a conversation."
      )

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.AdminRepliedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:conversation_id, :string)
        field(:conversation_state, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :user_replied do
      id("intercom.conversation.user.replied")
      resource(:conversation)
      verb(:watch)
      data_classification(:workspace_content)
      label("User replied")

      description("Receive Intercom webhook notifications when a user replies to a conversation.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.UserRepliedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:conversation_id, :string)
        field(:conversation_state, :string)
        field(:conversation_body, :string)
        field(:author_id, :string)
        field(:author_type, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :conversation_assigned do
      id("intercom.conversation.admin.assigned")
      resource(:conversation)
      verb(:watch)
      data_classification(:workspace_content)
      label("Conversation assigned")

      description("Receive Intercom webhook notifications when a conversation is assigned.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ConversationAssignedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:conversation_id, :string)
        field(:conversation_state, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end

    webhook :conversation_closed do
      id("intercom.conversation.admin.closed")
      resource(:conversation)
      verb(:watch)
      data_classification(:workspace_content)
      label("Conversation closed")

      description("Receive Intercom webhook notifications when a conversation is closed.")

      verification(%{
        kind: :intercom_webhook,
        signature: :hmac_sha256,
        header: "X-Hub-Signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.Intercom.Handlers.Triggers.ConversationClosedWebhook)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string,
          description: "Intercom webhook secret for signature verification."
        )
      end

      signal do
        field(:topic, :string)
        field(:change_type, :string)
        field(:delivery_id, :string)
        field(:conversation_id, :string)
        field(:conversation_state, :string)
        field(:app_id, :string)
        field(:created_at, :integer)
      end
    end
  end
end
