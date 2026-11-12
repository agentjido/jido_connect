defmodule Jido.Connect.Slack.UserViewLiveSmokeTest do
  @moduledoc """
  Live checks of the authorizing user's view against the Slack test
  workspace.

      MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  The test app subscribes the four message events as user events as well,
  so Slack also delivers messages from conversations that only the person
  who authorized the app sees. A person in the Slack client posted three
  such messages while the demo host ran in capture mode: one in
  `SLACK_NO_ACCESS_CHANNEL_ID`, which the bot has left, one that mentions
  the app in another public channel without the bot, and one in a DM of
  that person without the bot. The first test finds them in
  `SLACK_CAPTURE_DIR` by their authorization (`is_bot: false`), never by
  file name, replays each raw through `Jido.Connect.Slack.Webhook` with
  `SLACK_SIGNING_SECRET` and compares the signal with the message that the
  user token reads through `conversations.history`. The bot token cannot
  read any of the three conversations, and Slack sent no `app_mention` for
  the mention.

  With `JIDO_CONNECT_RECORD=1` the three deliveries become the fixtures
  `message_public_user_view`, `message_mention_user_view` and
  `message_im_user_view` in `test/fixtures/slack/captured`, sanitized and
  signed again with `LiveSmoke.replay_secret/0`. Their texts and links
  become placeholders: the offline tests need IDs, timestamps and
  authorizations, and the DM's text is a link into the workspace.

  The second test reads `SLACK_NO_ACCESS_CHANNEL_ID` through
  `slack.conversation.history` with a lease from
  `Jido.Connect.Slack.OAuth.user_credential_lease/3` around
  `SLACK_USER_TOKEN`. A single `conversations.history` call with Req
  outside the package is the reference for `ts` order and authors. The
  page must hold the bot message that the seed posted before the bot left
  and a message of the authorizing user. A lease from
  `bot_credential_lease/3` around `SLACK_BOT_TOKEN` gets `not_in_channel`.
  With `JIDO_CONNECT_RECORD=1` the user's page becomes
  `test/fixtures/slack/recorded/conversation_history_user_view.json`, with
  its texts as placeholders. Neither test writes to Slack.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Slack.{Client, OAuth, Webhook}
  alias Jido.Connect.Slack.TestSupport.LiveSlack
  alias Jido.Connect.WebhookDelivery

  @capture_env [
    "SLACK_BOT_TOKEN",
    "SLACK_USER_TOKEN",
    "SLACK_SIGNING_SECRET",
    "SLACK_CAPTURE_DIR",
    "SLACK_NO_ACCESS_CHANNEL_ID"
  ]

  # Message texts and the links in their blocks.
  @capture_fields ["text", "url"]

  @history_scopes ["channels:history", "groups:history", "im:history", "mpim:history"]

  @tag env!(@capture_env)
  test "captured user events from conversations without the bot verify and reach the message triggers",
       %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]
    bot_user = LiveSlack.user_id!(env["SLACK_BOT_TOKEN"])
    authorizing_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])
    captures = first_deliveries!(env)
    deliveries = user_view_deliveries!(captures, env, bot_user)

    if LiveSmoke.recording?() do
      for {spec, capture} <- deliveries do
        LiveSmoke.write_capture!(capture, :slack, spec.fixture,
          secret: secret,
          fields: @capture_fields
        )
      end
    end

    for {spec, capture} <- deliveries do
      payload = Jason.decode!(capture["body"])
      event = payload["event"]

      assert [%{"is_bot" => false, "user_id" => ^authorizing_user}] = payload["authorizations"]

      assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
               LiveSmoke.replay(capture, webhook: Webhook, secret: secret),
             "#{spec.kind} does not normalize"

      signal = Map.delete(signal, :delivery)
      assert {:ok, ^signal} = Webhook.normalize_signal(spec.trigger, payload)
      assert %{view: "user", viewer: ^authorizing_user} = signal

      stored = stored_message!(env["SLACK_USER_TOKEN"], event["channel"], event["ts"])
      assert signal.channel == event["channel"]
      assert signal.ts == stored["ts"], "#{spec.kind} ts"
      assert signal.user == stored["user"], "#{spec.kind} user"
      assert signal.text == stored["text"], "#{spec.kind} text"

      bot_error = read_error(env["SLACK_BOT_TOKEN"], event["channel"])

      assert bot_error in ["not_in_channel", "channel_not_found"],
             "#{spec.kind}: the bot reads it"

      assert_kind(spec, signal, captures, bot_user)

      IO.puts(
        "live_smoke slack: user view #{spec.kind} #{signal.channel} #{signal.ts} " <>
          "#{payload["event_id"]} verifies through #{spec.trigger}; the bot gets #{bot_error}"
      )
    end
  end

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_USER_TOKEN", "SLACK_NO_ACCESS_CHANNEL_ID"])
  test "a user lease reads the channel the bot left, where a bot lease is denied", %{env: env} do
    channel = env["SLACK_NO_ACCESS_CHANNEL_ID"]

    assert {:ok, %{"user_id" => user, "team_id" => team}} =
             Client.auth_test(env["SLACK_USER_TOKEN"])

    assert {:ok, %{"user_id" => bot_user}} = Client.auth_test(env["SLACK_BOT_TOKEN"])

    # The shape that exchange_code/2 returns. The workspace's user token
    # came from its own consent, not from this package's exchange.
    token = %{
      access_token: env["SLACK_BOT_TOKEN"],
      token_type: "bot",
      scope: @history_scopes,
      bot_user_id: bot_user,
      team: %{"id" => team},
      authed_user: %{
        id: user,
        access_token: env["SLACK_USER_TOKEN"],
        token_type: "user",
        scope: @history_scopes
      }
    }

    LiveSlack.record("conversation_history_user_view", fields: ["text"])
    assert {:ok, %{messages: messages, has_more: false}} = history(:user, token, channel)

    LiveSlack.skip_recording()

    assert {:error, %Connect.Error.ProviderError{provider: :slack, reason: "not_in_channel"}} =
             history(:bot, token, channel)

    %{status: 200, body: %{"ok" => true, "has_more" => false, "messages" => reference}} =
      LiveSlack.reference_request(env["SLACK_USER_TOKEN"], :get, "conversations.history",
        params: [channel: channel, limit: 100]
      )

    assert Enum.map(messages, &identity/1) == Enum.map(reference, &identity/1)
    assert Enum.all?(messages, &(&1.channel == channel))

    assert Enum.any?(messages, &(&1.user == bot_user and &1.bot_id != nil)),
           "no bot message from before the bot left"

    assert Enum.any?(messages, &(&1.user == user and &1.bot_id == nil and &1.subtype == nil)),
           "no message of the authorizing user"

    authors = Enum.map_join(messages, " ", &"#{&1.ts}:#{&1.user}#{if &1.bot_id, do: "/bot"}")

    IO.puts(
      "live_smoke slack: user lease read #{length(messages)} messages in #{channel} " <>
        "matching conversations.history (#{authors}); the bot lease got not_in_channel"
    )
  end

  defp history(profile, token, channel) do
    {owner_type, owner_id, lease_fun} =
      case profile do
        :user -> {:user, token.authed_user.id, &OAuth.user_credential_lease/3}
        :bot -> {:tenant, token.team["id"], &OAuth.bot_credential_lease/3}
      end

    connection =
      Connect.Connection.new!(%{
        id: "slack-live-#{profile}",
        provider: :slack,
        profile: profile,
        tenant_id: "live-smoke",
        owner_type: owner_type,
        owner_id: owner_id,
        status: :connected,
        scopes: @history_scopes
      })

    assert {:ok, lease} = lease_fun.(token, %{tenant_id: "live-smoke"}, connection: connection)

    Connect.invoke(
      Jido.Connect.Slack,
      "slack.conversation.history",
      %{channel: channel, conversation_type: "public_channel"},
      context:
        Connect.Context.new!(%{
          tenant_id: "live-smoke",
          actor: %{id: "live-smoke", type: :user},
          connection: connection
        }),
      credential_lease: lease
    )
  end

  defp identity(%{"ts" => ts} = message),
    do: {ts, message["user"], message["bot_id"], message["app_id"], message["subtype"]}

  defp identity(message),
    do: {message.ts, message.user, message.bot_id, message.app_id, message.subtype}

  defp assert_kind(%{kind: :mention}, signal, captures, bot_user) do
    assert signal.text =~ "<@#{bot_user}>"

    refute Enum.any?(captures, fn capture ->
             event = event(capture)
             event["type"] == "app_mention" and event["ts"] == signal.ts
           end),
           "Slack sent an app_mention for #{signal.ts}"
  end

  defp assert_kind(%{kind: :direct_message}, signal, _captures, _bot_user) do
    assert signal.conversation == %{id: signal.channel, type: "im"}
    assert signal.sender == %{id: signal.user}
    refute Map.has_key?(signal, :shared_messages)
  end

  defp assert_kind(_spec, _signal, _captures, _bot_user), do: :ok

  # The three user events of the capture session, each the first delivery
  # of its kind.
  defp user_view_deliveries!(captures, env, bot_user) do
    user_messages =
      Enum.filter(captures, fn capture ->
        payload = Jason.decode!(capture["body"])
        event = payload["event"]

        event["type"] == "message" and event["subtype"] == nil and
          match?([%{"is_bot" => false}], payload["authorizations"])
      end)

    specs = [
      %{
        kind: :no_bot_channel,
        fixture: "message_public_user_view",
        trigger: "message.channels",
        match: &(&1["channel"] == env["SLACK_NO_ACCESS_CHANNEL_ID"])
      },
      %{
        kind: :mention,
        fixture: "message_mention_user_view",
        trigger: "message.channels",
        match:
          &(&1["channel_type"] == "channel" and &1["channel"] != env["SLACK_NO_ACCESS_CHANNEL_ID"] and
              String.contains?(&1["text"] || "", "<@#{bot_user}>"))
      },
      %{
        kind: :direct_message,
        fixture: "message_im_user_view",
        trigger: "message.im",
        match: &(&1["channel_type"] == "im")
      }
    ]

    for spec <- specs do
      capture =
        Enum.find(user_messages, &spec.match.(event(&1))) ||
          flunk("no user event of kind #{spec.kind} in SLACK_CAPTURE_DIR")

      {spec, capture}
    end
  end

  # Event deliveries in capture order, without Slack's retries.
  defp first_deliveries!(env) do
    env["SLACK_CAPTURE_DIR"]
    |> Path.join("slack-events-*.json")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
    |> Enum.reject(&Map.has_key?(&1["headers"], "x-slack-retry-num"))
    |> Enum.sort_by(& &1["captured_at"])
  end

  defp event(capture), do: capture["body"] |> Jason.decode!() |> Map.fetch!("event")

  defp stored_message!(token, channel, ts) do
    %{status: 200, body: %{"ok" => true, "messages" => messages}} =
      LiveSlack.reference_request(token, :get, "conversations.history",
        params: [channel: channel, oldest: ts, latest: ts, inclusive: true, limit: 1]
      )

    Enum.find(messages, &(&1["ts"] == ts)) ||
      flunk("conversations.history has no message #{ts} in #{channel}")
  end

  defp read_error(token, channel) do
    %{status: 200, body: %{"ok" => false, "error" => error}} =
      LiveSlack.reference_request(token, :get, "conversations.history",
        params: [channel: channel, limit: 1]
      )

    error
  end
end
