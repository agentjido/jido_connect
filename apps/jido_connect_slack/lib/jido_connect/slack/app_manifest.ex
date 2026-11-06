defmodule Jido.Connect.Slack.AppManifest do
  @moduledoc """
  Builds Slack app manifests for local Jido Connect demos.

  The manifest is intentionally small: it configures a bot user, OAuth redirect
  URLs, and the scopes required by the first generated Slack actions. Event and
  interactivity URLs are opt-in so hosts can enable them after local routes are
  ready to answer Slack's verification requests.

  Every manifest turns on the Messages tab of the app's App Home and keeps it
  writable (`features.app_home`), so people can send the bot direct messages
  and share messages into its DM. Without it, Slack offers no DM with the
  app. The Home tab stays off, since the package publishes no Home view.

  The user view is opt-in as well. `:user_scopes` lists the scopes of the
  user token that the person who installs the app grants, under
  `oauth_config.scopes.user`, and `:user_events` the events the app receives
  through those user tokens, under `settings.event_subscriptions.user_events`.
  For the authorizing user's messages these are `channels:history`,
  `groups:history`, `im:history` and `mpim:history`, and `message.channels`,
  `message.groups`, `message.im` and `message.mpim`. User events need
  `include_events?: true`, which adds the events request URL, and Slack
  rejects a user event whose scope `:user_scopes` lacks. Without the two
  options the manifest has neither key.
  """

  @default_scopes [
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
  @event_scopes [
    "app_mentions:read",
    "channels:read",
    "channels:history",
    "groups:history",
    "im:history",
    "mpim:history",
    "files:read",
    "reactions:read"
  ]

  @type option ::
          {:name, String.t()}
          | {:description, String.t()}
          | {:bot_display_name, String.t()}
          | {:scopes, [String.t()]}
          | {:include_events?, boolean()}
          | {:include_interactivity?, boolean()}
          | {:user_scopes, [String.t()]}
          | {:user_events, [String.t()]}

  @doc """
  Builds a Slack manifest map for a public host URL.
  """
  @spec build(String.t(), [option()]) :: map()
  def build(base_url, opts \\ []) when is_binary(base_url) and is_list(opts) do
    base_url = String.trim_trailing(base_url, "/")
    include_events? = Keyword.get(opts, :include_events?, false)
    include_interactivity? = Keyword.get(opts, :include_interactivity?, false)
    scopes = scopes(opts, include_events?)

    %{
      display_information: %{
        name: Keyword.get(opts, :name, default_app_name()),
        description: Keyword.get(opts, :description, "Local Jido Connect Slack test app."),
        background_color: "#1f2937"
      },
      features: %{
        bot_user: %{
          display_name: Keyword.get(opts, :bot_display_name, "Jido Connect"),
          always_online: false
        },
        app_home: %{
          home_tab_enabled: false,
          messages_tab_enabled: true,
          messages_tab_read_only_enabled: false
        }
      },
      oauth_config: %{
        redirect_urls: [oauth_callback_url(base_url)],
        scopes: %{
          bot: scopes
        }
      },
      settings: %{
        org_deploy_enabled: false,
        socket_mode_enabled: false,
        token_rotation_enabled: false
      }
    }
    |> maybe_put_event_subscriptions(base_url, include_events?)
    |> maybe_put_interactivity(base_url, include_interactivity?)
    |> maybe_put_user_scopes(Keyword.get(opts, :user_scopes, []))
    |> maybe_put_user_events(Keyword.get(opts, :user_events, []), include_events?)
  end

  @doc """
  Builds Slack's app-creation URL with a URL-encoded JSON manifest.
  """
  @spec creation_url(map()) :: String.t()
  def creation_url(manifest) when is_map(manifest) do
    "https://api.slack.com/apps?" <>
      URI.encode_query(%{
        "new_app" => "1",
        "manifest_json" => Jason.encode!(manifest)
      })
  end

  @doc false
  @spec default_app_name() :: String.t()
  def default_app_name do
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "Jido Connect Dev #{suffix}"
  end

  @doc false
  @spec oauth_callback_url(String.t()) :: String.t()
  def oauth_callback_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/oauth/callback"

  @doc false
  @spec events_url(String.t()) :: String.t()
  def events_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/events"

  @doc false
  @spec interactivity_url(String.t()) :: String.t()
  def interactivity_url(base_url),
    do: String.trim_trailing(base_url, "/") <> "/integrations/slack/interactivity"

  defp scopes(opts, include_events?) do
    opts
    |> Keyword.get(:scopes, @default_scopes)
    |> Kernel.++(if include_events?, do: @event_scopes, else: [])
    |> Enum.uniq()
  end

  defp maybe_put_event_subscriptions(manifest, _base_url, false), do: manifest

  # No `scope_denied`: it belonged to workspace apps, which Slack retired in
  # August 2021.
  defp maybe_put_event_subscriptions(manifest, base_url, true) do
    put_in(manifest, [:settings, :event_subscriptions], %{
      request_url: events_url(base_url),
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
        "reaction_added",
        "reaction_removed"
      ]
    })
  end

  defp maybe_put_user_scopes(manifest, []), do: manifest

  defp maybe_put_user_scopes(manifest, scopes),
    do: put_in(manifest, [:oauth_config, :scopes, :user], scopes)

  defp maybe_put_user_events(manifest, [], _include_events?), do: manifest

  defp maybe_put_user_events(manifest, events, true),
    do: put_in(manifest, [:settings, :event_subscriptions, :user_events], events)

  defp maybe_put_user_events(_manifest, _events, false) do
    raise ArgumentError,
          "user_events need include_events?: true, which adds the events request URL"
  end

  defp maybe_put_interactivity(manifest, _base_url, false), do: manifest

  defp maybe_put_interactivity(manifest, base_url, true) do
    put_in(manifest, [:settings, :interactivity], %{
      is_enabled: true,
      request_url: interactivity_url(base_url)
    })
  end
end
