defmodule Jido.Connect.Slack.Triggers.Events.Messages do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  # The subtypes the webhook normalizer accepts as new human messages.
  @human_message_subtypes Jido.Connect.Slack.Webhook.Normalizer.human_message_subtypes()

  @subtype "Slack's subtype of a new message a person writes: file_share for a message with files, thread_broadcast for a thread reply also sent to the channel. Plain messages have none."
  @shared_messages "Messages shared natively into a direct message, one per attachment with is_share: channel and ts of the shared message, its author as user, its text and from_url. The person who shared them is the signal's user."
  @file_ids "IDs of the files of a file_share message. File content and links are not part of the signal."

  triggers do
    webhook :app_mention do
      id "slack.event.app_mention"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "App mention"
      description "Receive Slack Events API app_mention callbacks."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      handler Jido.Connect.Slack.Handlers.Triggers.AppMentionEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["app_mentions:read"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
      end
    end

    webhook :public_channel_message do
      id "slack.event.message.channels"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Public channel message"

      description "Receive Slack Events API message.channels callbacks for new public channel messages: plain messages, file shares and broadcast thread replies."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.PublicChannelMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :subtype, :string, enum: @human_message_subtypes, description: @subtype
        field :file_ids, {:array, :string}, description: @file_ids
      end
    end

    webhook :private_channel_message do
      id "slack.event.message.groups"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Private channel message"

      description "Receive Slack Events API message.groups callbacks for new private channel messages: plain messages, file shares and broadcast thread replies. Requires Slack groups:history for private channel history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.PrivateChannelMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["groups:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :subtype, :string, enum: @human_message_subtypes, description: @subtype
        field :file_ids, {:array, :string}, description: @file_ids
      end
    end

    webhook :direct_message do
      id "slack.event.message.im"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Direct message"

      description "Receive Slack Events API message.im callbacks for new direct messages: plain messages, file shares, broadcast thread replies and messages shared into the DM. Requires Slack im:history for direct message history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.DirectMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["im:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
        field :subtype, :string, enum: @human_message_subtypes, description: @subtype
        field :file_ids, {:array, :string}, description: @file_ids
        field :shared_messages, {:array, :map}, description: @shared_messages
      end
    end

    webhook :multi_person_direct_message do
      id "slack.event.message.mpim"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Multi-person direct message"

      description "Receive Slack Events API message.mpim callbacks for new multi-person direct messages: plain messages, file shares, broadcast thread replies and messages shared into the conversation. Requires Slack mpim:history for multi-person direct message history events."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.MultiPersonDirectMessageEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["mpim:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
        field :subtype, :string, enum: @human_message_subtypes, description: @subtype
        field :file_ids, {:array, :string}, description: @file_ids
        field :shared_messages, {:array, :map}, description: @shared_messages
      end
    end

    webhook :thread_reply do
      id "slack.event.message.thread_reply"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Thread reply"

      description "Receive Slack Events API message callbacks for new thread replies, including broadcast replies and excluding thread root messages."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{key: [:team_id, :channel, :thread_ts, :ts]}
      handler Jido.Connect.Slack.Handlers.Triggers.ThreadReplyEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history", "groups:history", "im:history", "mpim:history"]
      end

      signal do
        field :team_id, :string
        field :event_id, :string
        field :channel, :string
        field :channel_type, :string
        field :user, :string
        field :user_team, :string
        field :source_team, :string
        field :text, :string
        field :ts, :string
        field :thread_ts, :string
        field :event_ts, :string
        field :sender, :map
        field :conversation, :map
        field :subtype, :string, enum: @human_message_subtypes, description: @subtype
        field :file_ids, {:array, :string}, description: @file_ids
        field :shared_messages, {:array, :map}, description: @shared_messages
      end
    end
  end
end
