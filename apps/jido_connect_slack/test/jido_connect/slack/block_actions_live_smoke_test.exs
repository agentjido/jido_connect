defmodule Jido.Connect.Slack.BlockActionsLiveSmokeTest do
  @moduledoc """
  Live check of Block Kit buttons against the Slack test workspace.

      SLACK_LIVE_DESTRUCTIVE=true MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  The bot posted two messages with an Approve and a Reject button to the
  public channel, and a person clicked one button on each while the demo
  host ran in capture mode (`docs/live_smoke_tests.md`), so the clicks lie
  in `SLACK_CAPTURE_DIR` as `slack-interactivity-*.json`. The test takes
  the first two `block_actions` deliveries in capture order. Both messages
  stay in the channel.

  Each click is replayed raw through
  `Jido.Connect.Slack.Interactivity.verify_delivery/4` with
  `SLACK_SIGNING_SECRET` and `SLACK_APP_ID`. Its signal must name the
  authorizing user of `SLACK_USER_TOKEN`, who clicked, and the public
  channel. The bot token reads the clicked message through
  `conversations.history` with Req outside the package: its `ts` must be
  the signal's `message_ts`, its author the bot user and not the clicking
  user, and one of its actions blocks must hold a button with the signal's
  `block_id`, `action_id` and `value`.

  A new post gets a new `ts`, so the captured clicks cannot name it. The
  test therefore posts, through `slack.message.post`, one message per click
  whose blocks are a neutral section and the clicked actions block as Slack
  stores it, with a fallback text. Slack must store each post with that
  actions block, so the button a click names is one that
  `slack.message.post` sends. Both posts are deleted in the same test,
  because the history checks count the channel's messages.

  With `JIDO_CONNECT_RECORD=1` the first post's response becomes
  `chat_post_message_blocks.json`, and the clicks become the fixtures
  `block_actions_button_1` and `block_actions_button_2`, sanitized and
  signed again with `LiveSmoke.replay_secret/0`. `token` is redacted, and
  `response_url`, `trigger_id`, the workspace domain and the user and
  channel names become placeholders.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Slack.Interactivity
  alias Jido.Connect.Slack.TestSupport.LiveSlack
  alias Jido.Connect.WebhookDelivery

  @env [
    "SLACK_BOT_TOKEN",
    "SLACK_USER_TOKEN",
    "SLACK_SIGNING_SECRET",
    "SLACK_APP_ID",
    "SLACK_CAPTURE_DIR",
    "SLACK_PUBLIC_CHANNEL_ID"
  ]

  # `response_url` and `trigger_id` are temporary capabilities, `domain`
  # names the workspace, and `name` holds the user and channel names.
  @capture_fields ~w(response_url trigger_id domain name)

  @tag env!(@env)
  @tag write!(:slack)
  test "posts two button messages with blocks and replays the captured clicks on such buttons",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    secret = env["SLACK_SIGNING_SECRET"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]

    LiveSlack.skip_recording()
    clicking_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])
    bot_user = LiveSlack.user_id!(token)
    clicks = clicks!(env)

    if LiveSmoke.recording?() do
      for {capture, n} <- Enum.with_index(clicks, 1) do
        LiveSmoke.write_capture!(capture, :slack, "block_actions_button_#{n}",
          secret: secret,
          fields: @capture_fields
        )
      end
    end

    for {capture, n} <- Enum.with_index(clicks, 1) do
      assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
               LiveSmoke.replay(capture,
                 webhook: Interactivity,
                 secret: secret,
                 api_app_id: env["SLACK_APP_ID"]
               ),
             "click #{n} does not normalize"

      assert signal.user_id == clicking_user, "click #{n} user"
      assert signal.channel_id == channel, "click #{n} channel"

      clicked = stored_message!(token, channel, signal.message_ts)
      assert clicked["ts"] == signal.message_ts, "click #{n} message ts"
      assert clicked["user"] == bot_user, "click #{n} message author"
      refute clicked["user"] == signal.user_id, "click #{n} author is the clicking user"

      actions_block = clicked_block!(clicked, signal)

      if n == 1,
        do: LiveSlack.record("chat_post_message_blocks"),
        else: LiveSlack.skip_recording()

      text = "Button check #{n} from the jido_connect_slack live test: Approve or Reject."

      blocks = [
        %{"type" => "section", "text" => %{"type" => "mrkdwn", "text" => text}},
        actions_block
      ]

      post = post!(token, %{channel: channel, text: text, blocks: blocks})
      LiveSlack.skip_recording()

      assert post.channel == channel
      assert post.message["text"] == text
      assert actions_block in post.message["blocks"], "post #{n} response blocks"

      stored_post = stored_message!(token, channel, post.ts)
      assert stored_post["text"] == text
      assert actions_block in stored_post["blocks"], "post #{n} stored blocks"
      assert clicked_block!(stored_post, signal) == actions_block

      IO.puts(
        "live_smoke slack: click #{n} by #{signal.user_id} on #{signal.message_ts} " <>
          "value #{signal.value} matches conversations.history; posted #{post.ts} with its button"
      )
    end
  end

  # The first two block_actions deliveries in capture order.
  defp clicks!(env) do
    clicks =
      env["SLACK_CAPTURE_DIR"]
      |> Path.join("slack-interactivity-*.json")
      |> Path.wildcard()
      |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
      |> Enum.filter(&(payload(&1)["type"] == "block_actions"))
      |> Enum.sort_by(& &1["captured_at"])
      |> Enum.take(2)

    assert [_first, _second] = clicks,
           "SLACK_CAPTURE_DIR holds fewer than two block_actions clicks"

    clicks
  end

  defp payload(capture) do
    capture["body"] |> URI.decode_query() |> Map.fetch!("payload") |> Jason.decode!()
  end

  # The actions block of `message` that holds the clicked button.
  defp clicked_block!(message, signal) do
    assert [block] =
             for(
               %{"type" => "actions", "block_id" => block_id} = block <- message["blocks"] || [],
               block_id == signal.block_id,
               do: block
             )

    assert [%{"type" => "button", "value" => value}] =
             for(
               %{"action_id" => action_id} = button <- block["elements"],
               action_id == signal.action_id,
               do: button
             )

    assert value == signal.value
    block
  end

  # Posts through the action and deletes the post when the test exits.
  defp post!(token, input) do
    assert {:ok, %{ts: ts} = post} =
             LiveSlack.invoke("slack.message.post", input, token, ["chat:write"])

    LiveSlack.delete_on_exit(token, input.channel, ts)
    post
  end

  defp stored_message!(token, channel, ts) do
    %{status: 200, body: %{"ok" => true, "messages" => messages}} =
      LiveSlack.reference_request(token, :get, "conversations.history",
        params: [channel: channel, oldest: ts, latest: ts, inclusive: true, limit: 1]
      )

    assert [%{"ts" => ^ts} = message] = messages
    message
  end
end
