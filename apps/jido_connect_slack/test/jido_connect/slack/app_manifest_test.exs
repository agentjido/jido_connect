defmodule Jido.Connect.Slack.AppManifestTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Slack.AppManifest

  test "builds an oauth-only manifest by default" do
    manifest = AppManifest.build("https://demo.ngrok-free.app/", name: "Jido Connect Test")

    assert get_in(manifest, [:display_information, :name]) == "Jido Connect Test"

    assert get_in(manifest, [:oauth_config, :redirect_urls]) == [
             "https://demo.ngrok-free.app/integrations/slack/oauth/callback"
           ]

    assert get_in(manifest, [:oauth_config, :scopes, :bot]) == [
             "channels:read",
             "channels:manage",
             "channels:history",
             "groups:write",
             "im:write",
             "mpim:write",
             "chat:write",
             "files:write",
             "reactions:read",
             "reactions:write"
           ]

    refute get_in(manifest, [:settings, :event_subscriptions])
    refute get_in(manifest, [:settings, :interactivity])
  end

  test "can include events and interactivity routes" do
    manifest =
      AppManifest.build("https://demo.ngrok-free.app",
        include_events?: true,
        include_interactivity?: true
      )

    assert get_in(manifest, [:oauth_config, :scopes, :bot]) == [
             "channels:read",
             "channels:manage",
             "channels:history",
             "groups:write",
             "im:write",
             "mpim:write",
             "chat:write",
             "files:write",
             "reactions:read",
             "reactions:write",
             "app_mentions:read",
             "groups:history",
             "im:history",
             "mpim:history",
             "files:read"
           ]

    assert get_in(manifest, [:settings, :event_subscriptions]) == %{
             request_url: "https://demo.ngrok-free.app/integrations/slack/events",
             bot_events: [
               "app_mention",
               "message.channels",
               "message.groups",
               "message.im",
               "message.mpim",
               "app_home_opened",
               "channel_created",
               "channel_rename",
               "channel_archive",
               "channel_unarchive",
               "member_joined_channel",
               "member_left_channel",
               "file_created",
               "file_shared",
               "file_public",
               "file_deleted",
               "file_change",
               "app_uninstalled",
               "tokens_revoked",
               "scope_denied",
               "reaction_added",
               "reaction_removed"
             ]
           }

    assert get_in(manifest, [:settings, :interactivity]) == %{
             is_enabled: true,
             request_url: "https://demo.ngrok-free.app/integrations/slack/interactivity"
           }
  end

  test "adds user scopes and user events only when a host opts in" do
    user_scopes = ["channels:history", "groups:history", "im:history", "mpim:history"]
    user_events = ["message.channels", "message.groups", "message.im", "message.mpim"]
    base = [name: "Jido Connect Test", include_events?: true, include_interactivity?: true]

    default = AppManifest.build("https://demo.ngrok-free.app", base)

    manifest =
      AppManifest.build(
        "https://demo.ngrok-free.app",
        base ++ [user_scopes: user_scopes, user_events: user_events]
      )

    refute Map.has_key?(default.oauth_config.scopes, :user)
    refute Map.has_key?(default.settings.event_subscriptions, :user_events)

    assert manifest.oauth_config.scopes == %{
             bot: default.oauth_config.scopes.bot,
             user: user_scopes
           }

    assert manifest.settings.event_subscriptions ==
             Map.put(default.settings.event_subscriptions, :user_events, user_events)

    assert Map.delete(manifest, :oauth_config) |> Map.delete(:settings) ==
             Map.delete(default, :oauth_config) |> Map.delete(:settings)
  end

  test "user scopes need no event subscription, user events need the events URL" do
    manifest =
      AppManifest.build("https://demo.ngrok-free.app",
        user_scopes: ["channels:history"],
        user_events: []
      )

    assert manifest.oauth_config.scopes.user == ["channels:history"]
    refute get_in(manifest, [:settings, :event_subscriptions])

    refute Map.has_key?(
             AppManifest.build("https://demo.ngrok-free.app", user_scopes: []).oauth_config.scopes,
             :user
           )

    assert_raise ArgumentError, ~r/include_events\?/, fn ->
      AppManifest.build("https://demo.ngrok-free.app", user_events: ["message.channels"])
    end
  end

  test "encodes a Slack app creation URL" do
    manifest = AppManifest.build("https://demo.ngrok-free.app", name: "Jido Connect Test")
    url = AppManifest.creation_url(manifest)

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "api.slack.com"
    assert uri.path == "/apps"
    assert params["new_app"] == "1"

    assert Jason.decode!(params["manifest_json"])["display_information"]["name"] ==
             "Jido Connect Test"
  end
end
