defmodule Jido.Connect.Slack.Actions.Conversations do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_channels do
      id "slack.channel.list"
      resource :channel
      verb :list
      data_classification :workspace_metadata
      label "List channels"
      description "List Slack conversations visible to the installed app."
      handler Jido.Connect.Slack.Handlers.Actions.ListChannels
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :types, :string, default: "public_channel"
        field :exclude_archived, :boolean, default: true
        field :limit, :integer, default: 100
        field :cursor, :string
        field :team_id, :string
      end

      output do
        field :channels, {:array, :map}
        field :next_cursor, :string
      end
    end

    action :get_thread_replies do
      id "slack.thread.replies"
      resource :thread
      verb :read
      data_classification :message_content
      label "Get thread replies"
      description "Fetch replies for a Slack message thread."
      handler Jido.Connect.Slack.Handlers.Actions.GetThreadReplies
      effect :read

      access do
        auth [:bot, :user], default: :bot
        policies [:workspace_access]
        scopes ["channels:history"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack parent message timestamp."

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."

        field :limit, :integer, default: 100
        field :cursor, :string
        field :oldest, :string
        field :latest, :string
        field :inclusive, :boolean, default: false
      end

      output do
        field :channel, :string
        field :thread_ts, :string
        field :messages, {:array, :map}
        field :reply_count, :integer
        field :latest_reply, :string
        field :next_cursor, :string
        field :has_more, :boolean
      end
    end

    action :get_conversation_info do
      id "slack.conversation.info"
      resource :conversation
      verb :read
      data_classification :workspace_metadata
      label "Get conversation info"
      description "Get metadata for a Slack public channel, private channel, IM, or MPIM."
      handler Jido.Connect.Slack.Handlers.Actions.GetConversationInfo
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."

        field :include_locale, :boolean, default: false
      end

      output do
        field :channel, :string
        field :conversation, :map
      end
    end

    action :create_channel do
      id "slack.channel.create"
      resource :channel
      verb :create
      data_classification :workspace_metadata
      label "Create channel"
      description "Create a Slack public or private channel."
      handler Jido.Connect.Slack.Handlers.Actions.CreateChannel
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :name, :string, required?: true, example: "project-updates"
        field :is_private, :boolean, default: false
        field :team_id, :string
      end

      output do
        field :channel, :map
      end
    end

    action :archive_channel do
      id "slack.channel.archive"
      resource :channel
      verb :archive
      data_classification :workspace_metadata
      label "Archive channel"
      description "Archive a Slack conversation."
      handler Jido.Connect.Slack.Handlers.Actions.ArchiveChannel
      effect :destructive, confirmation: :always

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."
      end

      output do
        field :channel, :string
      end
    end

    action :unarchive_channel do
      id "slack.channel.unarchive"
      resource :channel
      verb :unarchive
      data_classification :workspace_metadata
      label "Unarchive channel"
      description "Unarchive a Slack conversation."
      handler Jido.Connect.Slack.Handlers.Actions.UnarchiveChannel
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"

        field :conversation_type, :string,
          description: "Optional Slack conversation type: public_channel or private_channel."
      end

      output do
        field :channel, :string
      end
    end

    action :rename_channel do
      id "slack.channel.rename"
      resource :channel
      verb :update
      data_classification :workspace_metadata
      label "Rename channel"
      description "Rename a Slack conversation."
      handler Jido.Connect.Slack.Handlers.Actions.RenameChannel
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :name, :string, required?: true, example: "project-updates"

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."
      end

      output do
        field :channel, :map
      end
    end

    action :invite_users do
      id "slack.conversation.invite"
      resource :conversation_member
      verb :create
      data_classification :workspace_metadata
      label "Invite users to channel"
      description "Invite one or more Slack users to a public or private channel."
      handler Jido.Connect.Slack.Handlers.Actions.InviteUsers
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :users, {:array, :string}, required?: true, description: "Slack user IDs to invite."
        field :force, :boolean, default: false

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."
      end

      output do
        field :channel, :map
        field :invited_users, {:array, :string}
        field :failed_users, {:array, :map}
        field :partial_failure, :boolean
      end
    end

    action :kick_user do
      id "slack.conversation.kick"
      resource :conversation_member
      verb :delete
      data_classification :workspace_metadata
      label "Remove user from channel"
      description "Remove a Slack user from a public or private channel."
      handler Jido.Connect.Slack.Handlers.Actions.KickUser
      effect :destructive, confirmation: :always

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:manage"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :user, :string, required?: true, description: "Slack user ID to remove."

        field :conversation_type, :string,
          description: "Optional Slack conversation type: public_channel or private_channel."
      end

      output do
        field :channel, :string
        field :user, :string
      end
    end

    action :open_conversation do
      id "slack.conversation.open"
      resource :conversation
      verb :create
      data_classification :workspace_metadata
      label "Open conversation"
      description "Open or resume a Slack DM or multi-person DM."
      handler Jido.Connect.Slack.Handlers.Actions.OpenConversation
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["im:write"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :users, {:array, :string}, description: "Slack user IDs for the DM or MPIM to open."

        field :channel, :string, description: "Existing Slack DM or MPIM channel ID to resume."

        field :return_im, :boolean, default: false
        field :prevent_creation, :boolean, default: false
      end

      output do
        field :channel, :string
        field :conversation, :map
      end
    end

    action :list_conversation_members do
      id "slack.conversation.members"
      resource :conversation_member
      verb :list
      data_classification :workspace_metadata
      label "List conversation members"
      description "List Slack user IDs that belong to a conversation."
      handler Jido.Connect.Slack.Handlers.Actions.ListConversationMembers
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["channels:read"], resolver: Jido.Connect.Slack.ScopeResolver
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"

        field :conversation_type, :string,
          description:
            "Optional Slack conversation type: public_channel, private_channel, im, or mpim."

        field :limit, :integer, default: 100
        field :cursor, :string
      end

      output do
        field :channel, :string
        field :members, {:array, :string}
        field :next_cursor, :string
      end
    end
  end
end
