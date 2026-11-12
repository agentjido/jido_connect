defmodule Jido.Connect.Slack.AppManifestTaskTest do
  # Mix.shell/1 is global.
  use ExUnit.Case, async: false

  alias Mix.Tasks.Jido.Connect.Slack.App.ManifestUrl

  @url "https://demo.ngrok-free.app"
  @user_scopes ["channels:history", "groups:history", "im:history", "mpim:history"]
  @user_events ["message.channels", "message.groups", "message.im", "message.mpim"]

  # What `--name "Jido Connect Test" --events --interactivity` wrote before
  # the Messages tab and the removal of `scope_denied`.
  @before %{
    "display_information" => %{
      "name" => "Jido Connect Test",
      "description" => "Local Jido Connect Slack test app.",
      "background_color" => "#1f2937"
    },
    "features" => %{
      "bot_user" => %{"display_name" => "Jido Connect", "always_online" => false}
    },
    "oauth_config" => %{
      "redirect_urls" => ["https://demo.ngrok-free.app/integrations/slack/oauth/callback"],
      "scopes" => %{
        "bot" => [
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
      }
    },
    "settings" => %{
      "org_deploy_enabled" => false,
      "socket_mode_enabled" => false,
      "token_rotation_enabled" => false,
      "event_subscriptions" => %{
        "request_url" => "https://demo.ngrok-free.app/integrations/slack/events",
        "bot_events" => [
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
      },
      "interactivity" => %{
        "is_enabled" => true,
        "request_url" => "https://demo.ngrok-free.app/integrations/slack/interactivity"
      }
    }
  }

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

  test "without user flags the manifest gains only the Messages tab and loses scope_denied",
       %{tmp_dir: tmp_dir} do
    {manifest, creation_url} = run_task!(tmp_dir, ["--events", "--interactivity"])

    assert manifest ==
             @before
             |> put_in(["features", "app_home"], %{
               "home_tab_enabled" => false,
               "messages_tab_enabled" => true,
               "messages_tab_read_only_enabled" => false
             })
             |> update_in(
               ["settings", "event_subscriptions", "bot_events"],
               &List.delete(&1, "scope_denied")
             )

    assert creation_manifest(creation_url) == manifest
    assert_received {:mix_shell, :info, [summary]}
    refute summary =~ "User scopes"
    refute summary =~ "User events"
  end

  test "--user-scopes and --user-events add the user view as comma-separated lists",
       %{tmp_dir: tmp_dir} do
    {plain, _url} = run_task!(Path.join(tmp_dir, "plain"), ["--events", "--interactivity"])

    {manifest, creation_url} =
      run_task!(Path.join(tmp_dir, "user"), [
        "--events",
        "--interactivity",
        "--user-scopes",
        "channels:history, groups:history,im:history,mpim:history",
        "--user-events",
        Enum.join(@user_events, ",")
      ])

    assert manifest ==
             plain
             |> put_in(["oauth_config", "scopes", "user"], @user_scopes)
             |> put_in(["settings", "event_subscriptions", "user_events"], @user_events)

    assert creation_manifest(creation_url) == manifest

    assert_received {:mix_shell, :info, [_plain_summary]}
    assert_received {:mix_shell, :info, [summary]}
    assert summary =~ "User scopes:              " <> Enum.join(@user_scopes, ",")
    assert summary =~ "User events:              " <> Enum.join(@user_events, ",")
  end

  test "--user-scopes works without --events, --user-events needs it", %{tmp_dir: tmp_dir} do
    {manifest, _url} =
      run_task!(Path.join(tmp_dir, "scopes"), ["--user-scopes", "channels:history"])

    assert manifest["oauth_config"]["scopes"]["user"] == ["channels:history"]
    refute Map.has_key?(manifest["settings"], "event_subscriptions")

    output = Path.join(tmp_dir, "events/manifest")

    assert_raise Mix.Error, ~r/--user-events needs --events/, fn ->
      ManifestUrl.run([
        "--url",
        @url,
        "--output",
        output,
        "--user-events",
        "message.channels"
      ])
    end

    refute File.exists?(output <> ".json")
  end

  defp run_task!(dir, args) do
    output = Path.join(dir, "manifest")

    ManifestUrl.run(["--url", @url, "--name", "Jido Connect Test", "--output", output] ++ args)

    {output |> Kernel.<>(".json") |> File.read!() |> Jason.decode!(),
     output |> Kernel.<>(".url") |> File.read!() |> String.trim()}
  end

  defp creation_manifest(creation_url) do
    creation_url
    |> URI.parse()
    |> Map.fetch!(:query)
    |> URI.decode_query()
    |> Map.fetch!("manifest_json")
    |> Jason.decode!()
  end
end
