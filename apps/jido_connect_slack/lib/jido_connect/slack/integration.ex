defmodule Jido.Connect.Slack do
  @moduledoc """
  Slack integration authored with the `Jido.Connect` Spark DSL.

  This module compiles into hidden generated adapter modules under
  provider-specific Actions and Plugin namespaces.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Slack.Actions.Conversations,
      Jido.Connect.Slack.Actions.Files,
      Jido.Connect.Slack.Actions.Identity,
      Jido.Connect.Slack.Actions.Messages,
      Jido.Connect.Slack.Actions.Pins,
      Jido.Connect.Slack.Actions.Presence,
      Jido.Connect.Slack.Actions.ReadState,
      Jido.Connect.Slack.Actions.Reactions,
      Jido.Connect.Slack.Actions.Users,
      Jido.Connect.Slack.Triggers.Events.Messages,
      Jido.Connect.Slack.Triggers.Events.Reactions,
      Jido.Connect.Slack.Triggers.Events.Channels,
      Jido.Connect.Slack.Triggers.Events.Files,
      Jido.Connect.Slack.Triggers.Events.Lifecycle
    ]

  integration do
    id :slack
    name "Slack"
    description "Slack workspace, channel, message, OAuth, and event tooling."
    category :collaboration
    docs ["https://docs.slack.dev/apis/web-api", "https://docs.slack.dev/events-api"]
  end

  catalog do
    package :jido_connect_slack
    status :available
    tags [:chat, :collaboration, :messaging]

    capability :app_manifest do
      kind :setup
      feature :slack_app_manifest
      label "Slack app manifest"
      description "Manifest-driven app setup for local and hosted OAuth installs."
    end

    capability :signed_requests do
      kind :webhook
      feature :signed_request_verification
      label "Signed request verification"
      description "Slack request signature verification and event normalization."
    end
  end

  auth do
    oauth2 :bot do
      default? true
      owner :tenant
      subject :bot
      label "Slack bot OAuth"
      authorize_url "https://slack.com/oauth/v2/authorize"
      token_url "https://slack.com/api/oauth.v2.access"
      callback_path "/integrations/slack/oauth/callback"
      token_field :access_token
      setup :oauth2_authorization_code
      credential_fields [:access_token]
      lease_fields [:access_token]

      scopes [
        "channels:read",
        "channels:manage",
        "channels:history",
        "groups:read",
        "groups:write",
        "groups:history",
        "im:read",
        "im:write",
        "im:history",
        "mpim:read",
        "mpim:write",
        "mpim:history",
        "app_mentions:read",
        "chat:write",
        "files:write",
        "pins:read",
        "pins:write",
        "reactions:read",
        "reactions:write",
        "team:read",
        "users:read"
      ]

      default_scopes [
        "channels:read",
        "channels:manage",
        "channels:history",
        "groups:write",
        "im:write",
        "mpim:write",
        "app_mentions:read",
        "chat:write",
        "files:write",
        "pins:read",
        "pins:write",
        "reactions:read",
        "reactions:write",
        "team:read",
        "users:read"
      ]

      pkce? false
      refresh? false
      revoke? false
    end

    oauth2 :user do
      owner :user
      subject :user
      label "Slack user OAuth"
      authorize_url "https://slack.com/oauth/v2/authorize"
      token_url "https://slack.com/api/oauth.v2.access"
      callback_path "/integrations/slack/oauth/callback"
      token_field :access_token
      setup :oauth2_authorization_code
      credential_fields [:access_token]
      lease_fields [:access_token]

      scopes [
        "channels:history",
        "channels:read",
        "channels:write",
        "chat:write",
        "emoji:read",
        "groups:history",
        "groups:read",
        "groups:write",
        "im:history",
        "im:read",
        "im:write",
        "mpim:history",
        "mpim:read",
        "mpim:write",
        "search:read",
        "users:read",
        "users.profile:read",
        "users.profile:write",
        "users:write"
      ]

      default_scopes [
        "channels:history",
        "channels:read",
        "channels:write",
        "chat:write",
        "emoji:read",
        "groups:history",
        "groups:read",
        "groups:write",
        "im:history",
        "im:read",
        "im:write",
        "mpim:history",
        "mpim:read",
        "mpim:write",
        "search:read",
        "users:read",
        "users.profile:read",
        "users.profile:write",
        "users:write"
      ]

      pkce? false
      refresh? false
      revoke? false
    end
  end

  policies do
    policy :workspace_access do
      label "Workspace access"
      description "Host verifies the actor may use this Slack workspace connection."
      subject {:connection, :owner}
      owner {:connection, :owner}
      decision :allow_operation
    end
  end
end
