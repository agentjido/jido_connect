defmodule Jido.Connect.Slack.Actions.Presence do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :get_presence do
      id "slack.presence.get"
      resource :presence
      verb :read
      data_classification :identity
      label "Get presence"
      description "Get the calling Slack user's availability and custom status."
      handler Jido.Connect.Slack.Handlers.Actions.GetPresence
      effect :read

      access do
        auth :user
        policies [:workspace_access]
        scopes ["users:read", "users.profile:read"]
      end

      output do
        field :availability, :map
        field :status, :map
      end
    end

    action :set_presence do
      id "slack.presence.set"
      resource :presence
      verb :update
      data_classification :identity
      label "Set presence"
      description "Set the calling Slack user's manual presence to auto or away."
      handler Jido.Connect.Slack.Handlers.Actions.SetPresence
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        policies [:workspace_access]
        scopes ["users:write"]
      end

      input do
        field :mode, :string, required?: true, enum: ["auto", "away"]
      end

      output do
        field :mode, :string
        field :submitted, :boolean
      end
    end

    action :set_status do
      id "slack.profile.status.set"
      resource :profile_status
      verb :update
      data_classification :identity
      label "Set custom status"
      description "Set the calling Slack user's custom status text, emoji, and optional expiry."
      handler Jido.Connect.Slack.Handlers.Actions.SetStatus
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        policies [:workspace_access]
        scopes ["users.profile:write"]
      end

      input do
        field :text, :string, required?: true
        field :emoji, :string, required?: true
        field :expires_at, :string, description: "ISO 8601 date-time for status expiry."
      end

      output do
        field :status, :map
        field :submitted, :boolean
      end
    end

    action :clear_status do
      id "slack.profile.status.clear"
      resource :profile_status
      verb :update
      data_classification :identity
      label "Clear custom status"
      description "Clear the calling Slack user's custom status."
      handler Jido.Connect.Slack.Handlers.Actions.ClearStatus
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        policies [:workspace_access]
        scopes ["users.profile:write"]
      end

      output do
        field :status, :map
        field :submitted, :boolean
      end
    end

    action :list_emoji do
      id "slack.emoji.list"
      resource :emoji
      verb :list
      data_classification :workspace_metadata
      label "List custom emoji"
      description "List Slack custom emoji images and aliases for the workspace."
      handler Jido.Connect.Slack.Handlers.Actions.ListEmoji
      effect :read

      access do
        auth :user
        policies [:workspace_access]
        scopes ["emoji:read"]
      end

      output do
        field :emoji, {:array, :map}
        field :count, :integer
      end
    end
  end
end
