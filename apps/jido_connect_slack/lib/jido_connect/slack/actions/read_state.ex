defmodule Jido.Connect.Slack.Actions.ReadState do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_unread_messages do
      id "slack.message.unread.list"
      resource :message
      verb :list
      data_classification :message_content
      label "List unread messages"

      description "List unread messages from one Slack conversation or the calling user's conversations."

      handler Jido.Connect.Slack.Handlers.Actions.ListUnreadMessages
      effect :read

      access do
        auth :user
        policies [:workspace_access]

        scopes [
                 "channels:read",
                 "groups:read",
                 "im:read",
                 "mpim:read",
                 "channels:history",
                 "groups:history",
                 "im:history",
                 "mpim:history"
               ],
               resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string

        field :conversation_type, :string,
          enum: ["public_channel", "private_channel", "im", "mpim"]

        field :limit, :integer, default: 20
      end

      output do
        field :messages, {:array, :map}
        field :conversations, {:array, :map}
        field :count, :integer
        field :truncated, :boolean
        field :coverage, :map
      end
    end

    action :mark_conversation_read do
      id "slack.conversation.mark_read"
      resource :conversation_read_state
      verb :update
      data_classification :message_content
      label "Mark conversation read"
      description "Move the calling Slack user's read cursor to one exact message timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.MarkConversationRead
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        policies [:workspace_access]
        scopes ["channels:write"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack message timestamp."

        field :conversation_type, :string,
          enum: ["public_channel", "private_channel", "im", "mpim"]
      end

      output do
        field :channel, :string
        field :ts, :string
        field :marked, :boolean
      end
    end
  end
end
