defmodule Jido.Connect.Slack.Actions.Messages do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :post_message do
      id "slack.message.post"
      resource :message
      verb :create
      data_classification :message_content
      label "Post message"
      description "Post a message to a Slack channel or conversation."
      handler Jido.Connect.Slack.Handlers.Actions.PostMessage
      effect :write, confirmation: :required_for_ai

      access do
        auth [:bot, :user], default: :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :text, :string, required?: true
        field :thread_ts, :string
        field :reply_broadcast, :boolean, default: false
      end

      output do
        field :channel, :string
        field :ts, :string
        field :message, :map
      end
    end

    action :search_messages do
      id "slack.message.search"
      resource :message
      verb :search
      data_classification :message_content
      label "Search messages"
      description "Search Slack messages with query helpers and pagination."
      handler Jido.Connect.Slack.Handlers.Actions.SearchMessages
      effect :read

      access do
        auth :user
        policies [:workspace_access]
        scopes ["search:read"]
      end

      input do
        field :query, :string, required?: true

        field :in, :string,
          description:
            "Optional Slack search in: qualifier value, such as #general, group_name, or <@U012AB3CD>."

        field :from, :string,
          description:
            "Optional Slack search from: qualifier value, such as <@U012AB3CD> or botname."

        field :before, :string, description: "Optional Slack search before: date qualifier."
        field :after, :string, description: "Optional Slack search after: date qualifier."
        field :on, :string, description: "Optional Slack search on: date qualifier."
        field :has, :string, description: "Optional Slack search has: qualifier value."
        field :sort, :string, enum: ["score", "timestamp"], default: "score"
        field :sort_dir, :string, enum: ["asc", "desc"], default: "desc"
        field :count, :integer, default: 20
        field :page, :integer, default: 1
        field :cursor, :string
        field :highlight, :boolean, default: false
        field :team_id, :string
      end

      output do
        field :query, :string
        field :messages, {:array, :map}
        field :total_count, :integer
        field :pagination, :map
        field :paging, :map
        field :next_cursor, :string
      end
    end

    action :post_ephemeral do
      id "slack.message.post_ephemeral"
      resource :message
      verb :create
      data_classification :message_content
      label "Post ephemeral message"
      description "Post an ephemeral Slack message to one user in a channel or conversation."
      handler Jido.Connect.Slack.Handlers.Actions.PostEphemeral
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :user, :string, required?: true, example: "U012AB3CD"
        field :text, :string, required?: true
        field :thread_ts, :string
        field :blocks, {:array, :map}
      end

      output do
        field :channel, :string
        field :user, :string
        field :message_ts, :string
      end
    end

    action :schedule_message do
      id "slack.message.schedule"
      resource :message
      verb :create
      data_classification :message_content
      label "Schedule message"
      description "Schedule a Slack message to post to a channel or conversation."
      handler Jido.Connect.Slack.Handlers.Actions.ScheduleMessage
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :text, :string, required?: true

        field :post_at, :integer,
          required?: true,
          description: "Unix timestamp in seconds for when Slack should post the message."

        field :thread_ts, :string
        field :reply_broadcast, :boolean, default: false
        field :blocks, {:array, :map}
      end

      output do
        field :channel, :string
        field :scheduled_message_id, :string
        field :post_at, :integer
        field :message, :map
      end
    end

    action :unschedule_message do
      id "slack.message.unschedule"
      resource :message
      verb :cancel
      data_classification :message_content
      label "Unschedule message"
      description "Cancel a Slack scheduled message before it posts."
      handler Jido.Connect.Slack.Handlers.Actions.UnscheduleMessage
      effect :destructive, confirmation: :always

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"

        field :scheduled_message_id, :string,
          required?: true,
          description: "Slack scheduled message ID returned by chat.scheduleMessage."
      end

      output do
        field :channel, :string
        field :scheduled_message_id, :string
      end
    end

    action :update_message do
      id "slack.message.update"
      resource :message
      verb :update
      data_classification :message_content
      label "Update message"
      description "Update a Slack message by channel and timestamp."
      handler Jido.Connect.Slack.Handlers.Actions.UpdateMessage
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack message timestamp."
        field :text, :string
        field :blocks, {:array, :map}
      end

      output do
        field :channel, :string
        field :ts, :string
        field :message, :map
      end
    end

    action :delete_message do
      id "slack.message.delete"
      resource :message
      verb :delete
      data_classification :message_content
      label "Delete message"

      description """
      Delete a Slack message by channel and timestamp. Slack permits bot tokens
      to delete only messages posted by that bot; user tokens may delete only
      messages that user can delete in Slack.
      """

      handler Jido.Connect.Slack.Handlers.Actions.DeleteMessage
      effect :destructive, confirmation: :always

      access do
        auth [:bot, :user], default: :bot
        policies [:workspace_access]
        scopes ["chat:write"]
      end

      input do
        field :channel, :string, required?: true, example: "C012AB3CD"
        field :ts, :string, required?: true, description: "Slack message timestamp."
      end

      output do
        field :channel, :string
        field :ts, :string
      end
    end
  end
end
