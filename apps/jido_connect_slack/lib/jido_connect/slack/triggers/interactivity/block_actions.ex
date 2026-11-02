defmodule Jido.Connect.Slack.Triggers.Interactivity.BlockActions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  # Button clicks arrive at the app's interactivity request URL as signed
  # `block_actions` form bodies, which
  # `Jido.Connect.Slack.Interactivity.verify_delivery/4` verifies and
  # normalizes; `Jido.Connect.Slack.BlockAction` describes the signal.
  # Receiving a click needs no OAuth scope beyond the app's install. Slack
  # sends no delivery ID, so dedupe keys on the click's own identity.

  triggers do
    webhook :block_actions do
      id "slack.interactivity.block_actions"
      resource :block_action
      verb :watch
      data_classification :workspace_content
      label "Button click"

      description "Receive clicks on Block Kit buttons in Slack messages from signed interactivity block_actions requests. A click on one button in a message yields a signal with the clicking user, the message and the button's IDs and opaque value; other block actions yield no signal."

      verification %{
        kind: :slack_signed_request,
        signature_header: "x-slack-signature",
        timestamp_header: "x-slack-request-timestamp"
      }

      dedupe %{
        key: [
          :team_id,
          :channel_id,
          :message_ts,
          :user_id,
          :block_id,
          :action_id,
          :value,
          :action_ts
        ]
      }

      handler Jido.Connect.Slack.Handlers.Triggers.BlockActionsInteraction

      access do
        auth :bot
        policies [:workspace_access]
      end

      signal do
        field :api_app_id, :string, required?: true
        field :team_id, :string, required?: true
        field :enterprise_id, :string
        field :user_id, :string, required?: true, description: "User who clicked, from user.id."
        field :user_team_id, :string

        field :channel_id, :string,
          required?: true,
          description: "Channel of the message that holds the button."

        field :message_ts, :string,
          required?: true,
          description: "ts of the message that holds the button."

        field :thread_ts, :string, description: "thread_ts of that message, when Slack sends it."
        field :action_id, :string, required?: true
        field :block_id, :string, required?: true

        field :value, :string,
          required?: true,
          description: "The button's opaque value, up to 2,000 characters."

        field :action_ts, :string, required?: true, description: "Slack's time of the click."
      end
    end
  end
end
