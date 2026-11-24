defmodule Mix.Tasks.Jido.Connect.Slack.App.ManifestUrl do
  @moduledoc """
  Generates a Slack app creation URL from a manifest.

      mix jido.connect.slack.app.manifest_url
      mix jido.connect.slack.app.manifest_url --url https://example.ngrok-free.app
      mix jido.connect.slack.app.manifest_url --events --interactivity --open

  If `--url` is omitted, the task uses `JIDO_SLACK_PUBLIC_URL`,
  `JIDO_PUBLIC_URL`, or a running ngrok HTTPS tunnel from
  `http://127.0.0.1:4040/api/tunnels`.

  Every manifest has a writable Messages tab, so people can DM the bot.
  For the authorizing user's view, `--user-scopes` and `--user-events` take
  comma-separated lists for the manifest's user scopes and user events.
  User events need `--events`, which adds the events request URL:

      mix jido.connect.slack.app.manifest_url --events --interactivity \\
        --user-scopes channels:history,groups:history,im:history,mpim:history \\
        --user-events message.channels,message.groups,message.im,message.mpim
  """

  use Mix.Task

  alias Jido.Connect.Dev.PublicUrl
  alias Jido.Connect.Slack.AppManifest

  @shortdoc "Generates a Slack app manifest creation URL"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          bot_name: :string,
          description: :string,
          events: :boolean,
          interactivity: :boolean,
          name: :string,
          open: :boolean,
          output: :string,
          url: :string,
          user_events: :string,
          user_scopes: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    user_scopes = list_option(opts, :user_scopes)
    user_events = list_option(opts, :user_events)
    include_events? = Keyword.get(opts, :events, false)

    if user_events != [] and not include_events? do
      Mix.raise("--user-events needs --events, which adds the events request URL")
    end

    base_url = PublicUrl.resolve!(opts, ["JIDO_SLACK_PUBLIC_URL", "JIDO_PUBLIC_URL"])

    manifest =
      AppManifest.build(base_url,
        name: Keyword.get(opts, :name, AppManifest.default_app_name()),
        description: Keyword.get(opts, :description, "Local Jido Connect Slack test app."),
        bot_display_name: Keyword.get(opts, :bot_name, "Jido Connect"),
        include_events?: include_events?,
        include_interactivity?: Keyword.get(opts, :interactivity, false),
        user_scopes: user_scopes,
        user_events: user_events
      )

    creation_url = AppManifest.creation_url(manifest)
    output = Keyword.get(opts, :output, ".secrets/slack-app-manifest")

    write_outputs!(output, manifest, creation_url)
    print_summary(base_url, manifest, creation_url, output)
    maybe_open(creation_url, opts)
  end

  defp list_option(opts, key) do
    opts
    |> Keyword.get(key, "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp write_outputs!(output, manifest, creation_url) do
    File.mkdir_p!(Path.dirname(output))
    File.write!(output <> ".json", Jason.encode!(manifest, pretty: true))
    File.write!(output <> ".url", creation_url <> "\n")
  end

  defp print_summary(base_url, manifest, creation_url, output) do
    scopes = get_in(manifest, [:oauth_config, :scopes, :bot])
    events? = get_in(manifest, [:settings, :event_subscriptions]) != nil
    interactivity? = get_in(manifest, [:settings, :interactivity]) != nil

    Mix.shell().info("""
    Wrote #{output}.json
    Wrote #{output}.url

    Slack app manifest:
    Name:                     #{get_in(manifest, [:display_information, :name])}
    Public URL:               #{base_url}
    OAuth Redirect URL:       #{AppManifest.oauth_callback_url(base_url)}
    Events Request URL:       #{AppManifest.events_url(base_url)}#{included(events?, "--events")}
    Interactivity Request URL: #{AppManifest.interactivity_url(base_url)}#{included(interactivity?, "--interactivity")}
    Bot scopes:               #{Enum.join(scopes, ",")}
    #{user_view(manifest)}
    Open this URL to create the Slack app:
    #{creation_url}

    After Slack creates the app, copy these into .env:
    SLACK_CLIENT_ID=
    SLACK_CLIENT_SECRET=
    SLACK_SIGNING_SECRET=
    SLACK_BOT_TOKEN=
    """)
  end

  defp included(true, _flag), do: " (included)"
  defp included(false, flag), do: " (not included; pass #{flag})"

  # Lines for the user view, only when the manifest has one.
  defp user_view(manifest) do
    [
      {"User scopes:              ", get_in(manifest, [:oauth_config, :scopes, :user])},
      {"User events:              ",
       get_in(manifest, [:settings, :event_subscriptions, :user_events])}
    ]
    |> Enum.reject(fn {_label, values} -> values in [nil, []] end)
    |> Enum.map_join(fn {label, values} -> label <> Enum.join(values, ",") <> "\n" end)
  end

  defp maybe_open(creation_url, opts) do
    if Keyword.get(opts, :open, false) do
      System.cmd("open", [creation_url])
      :ok
    end
  end
end
