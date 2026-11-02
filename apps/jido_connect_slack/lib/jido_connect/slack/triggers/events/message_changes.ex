defmodule Jido.Connect.Slack.Triggers.Events.MessageChanges do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  # Edits and deletions arrive through the four message subscriptions as a
  # `message` event with the subtype `message_changed` or `message_deleted`;
  # `Jido.Connect.Slack.MessageChange` describes the signal. A deleted
  # thread parent with replies arrives as a `message_changed` with a
  # tombstone, which the deletion triggers take. Each notification has its
  # own `event_id`, so dedupe keeps two edits of the same message apart.

  @verification %{
    kind: :slack_signed_request,
    signature_header: "x-slack-signature",
    timestamp_header: "x-slack-request-timestamp"
  }

  @source_ts "ts of the edited or deleted message, from message.ts of an edit or a tombstone and deleted_ts of a deletion. With channel it names the original message; it is not the ts of this notification."
  @notification_ts "ts of this notification. Slack gives every edit and deletion a new one."
  @event_ts "Slack's event_ts of this notification."
  @changed_subtype "Always message_changed: an edit, marked by a new message.edited."
  @changed_thread_ts "thread_ts of the edited message, for a thread reply or a thread parent."
  @changed_user "Author of the edited message."
  @editor "User who made the edit, from message.edited.user."
  @edited_ts "Time of the edit, from message.edited.ts."
  @text "Full text after the edit, as Slack stores it. An empty string when Slack stores an empty text, as after an edit to an empty text beside an attachment; beside blocks Slack stores their text."
  @deleted_subtype "Always message_deleted."
  @deleted_thread_ts "thread_ts of the deleted message, from message of a tombstone and otherwise from previous_message when Slack sends it."
  @deleted_user "Author of the deleted message, from previous_message when Slack sends it and it is no tombstone. Slack does not say who deleted it."

  triggers do
    webhook :public_channel_message_changed do
      id "slack.event.message.channels.changed"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Public channel message edit"

      description "Receive edits of public channel messages from Slack Events API message.channels callbacks with the subtype message_changed and a new message.edited. Other message_changed callbacks, such as link unfurls, reply count updates or tombstones, yield no signal."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.PublicChannelMessageChangedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_changed"],
          description: @changed_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @changed_thread_ts
        field :user, :string, description: @changed_user
        field :bot_id, :string
        field :app_id, :string
        field :editor, :string, description: @editor
        field :edited_ts, :string, description: @edited_ts
        field :text, :string, description: @text
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :public_channel_message_deleted do
      id "slack.event.message.channels.deleted"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Public channel message deletion"

      description "Receive deletions of public channel messages from Slack Events API message.channels callbacks with the subtype message_deleted, or message_changed with a tombstone for a deleted thread parent with replies. The signal carries no message text."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.PublicChannelMessageDeletedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_deleted"],
          description: @deleted_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @deleted_thread_ts
        field :user, :string, description: @deleted_user
        field :bot_id, :string
        field :app_id, :string
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :private_channel_message_changed do
      id "slack.event.message.groups.changed"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Private channel message edit"

      description "Receive edits of private channel messages from Slack Events API message.groups callbacks with the subtype message_changed and a new message.edited. Other message_changed callbacks, such as link unfurls, reply count updates or tombstones, yield no signal. Requires Slack groups:history for private channel history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.PrivateChannelMessageChangedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["groups:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_changed"],
          description: @changed_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @changed_thread_ts
        field :user, :string, description: @changed_user
        field :bot_id, :string
        field :app_id, :string
        field :editor, :string, description: @editor
        field :edited_ts, :string, description: @edited_ts
        field :text, :string, description: @text
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :private_channel_message_deleted do
      id "slack.event.message.groups.deleted"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Private channel message deletion"

      description "Receive deletions of private channel messages from Slack Events API message.groups callbacks with the subtype message_deleted, or message_changed with a tombstone for a deleted thread parent with replies. The signal carries no message text. Requires Slack groups:history for private channel history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.PrivateChannelMessageDeletedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["groups:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_deleted"],
          description: @deleted_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @deleted_thread_ts
        field :user, :string, description: @deleted_user
        field :bot_id, :string
        field :app_id, :string
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :direct_message_changed do
      id "slack.event.message.im.changed"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Direct message edit"

      description "Receive edits of direct messages from Slack Events API message.im callbacks with the subtype message_changed and a new message.edited. Other message_changed callbacks, such as link unfurls, reply count updates or tombstones, yield no signal. Requires Slack im:history for direct message history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.DirectMessageChangedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["im:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_changed"],
          description: @changed_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @changed_thread_ts
        field :user, :string, description: @changed_user
        field :bot_id, :string
        field :app_id, :string
        field :editor, :string, description: @editor
        field :edited_ts, :string, description: @edited_ts
        field :text, :string, description: @text
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :direct_message_deleted do
      id "slack.event.message.im.deleted"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Direct message deletion"

      description "Receive deletions of direct messages from Slack Events API message.im callbacks with the subtype message_deleted, or message_changed with a tombstone for a deleted thread parent with replies. The signal carries no message text. Requires Slack im:history for direct message history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.DirectMessageDeletedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["im:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_deleted"],
          description: @deleted_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @deleted_thread_ts
        field :user, :string, description: @deleted_user
        field :bot_id, :string
        field :app_id, :string
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :multi_person_direct_message_changed do
      id "slack.event.message.mpim.changed"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Multi-person direct message edit"

      description "Receive edits of multi-person direct messages from Slack Events API message.mpim callbacks with the subtype message_changed and a new message.edited. Other message_changed callbacks, such as link unfurls, reply count updates or tombstones, yield no signal. Requires Slack mpim:history for multi-person direct message history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.MultiPersonDirectMessageChangedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["mpim:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_changed"],
          description: @changed_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @changed_thread_ts
        field :user, :string, description: @changed_user
        field :bot_id, :string
        field :app_id, :string
        field :editor, :string, description: @editor
        field :edited_ts, :string, description: @edited_ts
        field :text, :string, description: @text
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end

    webhook :multi_person_direct_message_deleted do
      id "slack.event.message.mpim.deleted"
      resource :message
      verb :watch
      data_classification :workspace_content
      label "Multi-person direct message deletion"

      description "Receive deletions of multi-person direct messages from Slack Events API message.mpim callbacks with the subtype message_deleted, or message_changed with a tombstone for a deleted thread parent with replies. The signal carries no message text. Requires Slack mpim:history for multi-person direct message history events."

      verification @verification
      dedupe %{key: [:team_id, :event_id]}
      handler Jido.Connect.Slack.Handlers.Triggers.MultiPersonDirectMessageDeletedEvent

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["mpim:history"]
      end

      signal do
        field :team_id, :string, required?: true
        field :event_id, :string, required?: true
        field :channel, :string, required?: true
        field :channel_type, :string

        field :subtype, :string,
          required?: true,
          enum: ["message_deleted"],
          description: @deleted_subtype

        field :ts, :string, required?: true, description: @source_ts
        field :thread_ts, :string, description: @deleted_thread_ts
        field :user, :string, description: @deleted_user
        field :bot_id, :string
        field :app_id, :string
        field :notification_ts, :string, description: @notification_ts
        field :event_ts, :string, description: @event_ts
      end
    end
  end
end
