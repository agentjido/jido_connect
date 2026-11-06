defmodule Jido.Connect.Slack.AppManifestLiveSmokeTest do
  @moduledoc """
  Live check of the generated app manifest against Slack's manifest schema.

      MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  `mix jido.connect.slack.app.manifest_url` writes the manifest for the base
  URL in `JIDO_PUBLIC_URL`, and Slack's `apps.manifest.validate` checks it
  with the app configuration token in `SLACK_CONFIG_TOKEN`. The tests
  validate the default manifest, the manifest of the test app with events
  and interactivity, and that manifest with the user scopes and user events
  of the user view. Every one carries the writable Messages tab. The call
  passes no `app_id`, so Slack only checks the manifest and no app is
  created, changed or installed. A running tunnel is not needed.

  A configuration token expires 12 hours after it is issued. Renew it with
  Slack's `tooling.tokens.rotate` and `SLACK_CONFIG_REFRESH_TOKEN` outside
  the tests; each rotation also replaces the refresh token.

  The tests record nothing, also with `JIDO_CONNECT_RECORD=1`, since no
  offline test replays Slack's answers.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Slack.TestSupport.LiveSlack
  alias Mix.Tasks.Jido.Connect.Slack.App.ManifestUrl

  @env ["SLACK_CONFIG_TOKEN", "JIDO_PUBLIC_URL"]
  @user_view [
    "--user-scopes",
    "channels:history,groups:history,im:history,mpim:history",
    "--user-events",
    "message.channels,message.groups,message.im,message.mpim"
  ]

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    tmp_dir = Path.join(System.tmp_dir!(), "slack-manifest-#{System.unique_integer([:positive])}")

    on_exit(fn ->
      Mix.shell(shell)
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  @tag env!(@env)
  test "apps.manifest.validate accepts the default manifest", %{env: env, tmp_dir: tmp_dir} do
    manifest = manifest!(env, tmp_dir, [])
    refute Map.has_key?(manifest["settings"], "event_subscriptions")

    LiveSlack.validate_manifest!(env["SLACK_CONFIG_TOKEN"], manifest)
  end

  @tag env!(@env)
  test "apps.manifest.validate accepts the manifest with events and interactivity",
       %{env: env, tmp_dir: tmp_dir} do
    manifest = manifest!(env, tmp_dir, ["--events", "--interactivity"])
    refute "scope_denied" in manifest["settings"]["event_subscriptions"]["bot_events"]

    LiveSlack.validate_manifest!(env["SLACK_CONFIG_TOKEN"], manifest)
  end

  @tag env!(@env)
  test "apps.manifest.validate accepts the manifest with the user view",
       %{env: env, tmp_dir: tmp_dir} do
    manifest = manifest!(env, tmp_dir, ["--events", "--interactivity" | @user_view])

    assert %{"user" => ["channels:history", "groups:history", "im:history", "mpim:history"]} =
             manifest["oauth_config"]["scopes"]

    assert %{"user_events" => ["message.channels" | _rest]} =
             manifest["settings"]["event_subscriptions"]

    LiveSlack.validate_manifest!(env["SLACK_CONFIG_TOKEN"], manifest)
  end

  # Runs the task as a developer would and reads the manifest it wrote.
  defp manifest!(env, tmp_dir, args) do
    output = Path.join(tmp_dir, "manifest")
    ManifestUrl.run(["--url", env["JIDO_PUBLIC_URL"], "--output", output] ++ args)
    manifest = output |> Kernel.<>(".json") |> File.read!() |> Jason.decode!()

    assert manifest["features"]["app_home"] == %{
             "home_tab_enabled" => false,
             "messages_tab_enabled" => true,
             "messages_tab_read_only_enabled" => false
           }

    manifest
  end
end
