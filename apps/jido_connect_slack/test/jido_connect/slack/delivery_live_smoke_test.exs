defmodule Jido.Connect.Slack.DeliveryLiveSmokeTest do
  @moduledoc """
  Live checks of message delivery against the Slack test workspace.

      SLACK_LIVE_DESTRUCTIVE=true MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  The delivery check posts one text with a link to the public channel, as a
  reply into the prepared thread and into the bot DM that
  `slack.conversation.open` opens with the authorizing user, whom `auth.test`
  of the user token names. Each post is compared with what Slack stores, read
  with Req outside the package, and deleted again in the same test, because
  the conversation history and thread checks read the prepared data.

  The `conversations.open` checks open the existing bot DM, with and without
  `return_im`, and the group DM, and are refused an unknown user; they run
  without the write gate. The refusal check posts to the channel the bot has
  left. With `JIDO_CONNECT_RECORD=1` these checks record the responses that the
  offline tests replay.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Slack.Client
  alias Jido.Connect.Slack.TestSupport.LiveSlack

  @link "https://example.com/jido-connect/delivery-check"
  @text "Delivery check from the jido_connect_slack live test: " <>
          "<#{@link}|open the delivery check> – " <>
          String.duplicate("This sentence pads the text past 512 bytes. ", 12)

  # The parameters slack.conversation.open sends with its defaults.
  @open_defaults %{return_im: false, prevent_creation: false}

  # No Slack user has this ID.
  @unknown_user "U0000000000"

  # A group DM's name and purpose list the members' Slack user names.
  @conversation_fields ["name", "name_normalized", "value"]

  @delivery_env [
    "SLACK_BOT_TOKEN",
    "SLACK_USER_TOKEN",
    "SLACK_PUBLIC_CHANNEL_ID",
    "SLACK_THREAD_TS",
    "SLACK_DM_CHANNEL_ID"
  ]

  @tag env!(@delivery_env)
  @tag write!(:slack)
  test "posts text with a link to a channel, into a thread and into a DM opened by slack.conversation.open",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    thread_ts = env["SLACK_THREAD_TS"]
    authorizing_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])

    # The lease carries only the access token, so the default client runs.
    LiveSlack.skip_recording()

    open_input = %{users: [authorizing_user]}

    assert {:ok, %{channel: dm}} =
             LiveSlack.invoke("slack.conversation.open", open_input, token, ["im:write"])

    assert dm == env["SLACK_DM_CHANNEL_ID"]

    LiveSlack.record("chat_post_message_channel")
    channel_post = post!(token, %{channel: channel, text: @text})

    LiveSlack.record("chat_post_message_thread_reply")
    reply = post!(token, %{channel: channel, text: @text, thread_ts: thread_ts})

    LiveSlack.skip_recording()
    dm_post = post!(token, %{channel: dm, text: @text})

    for {post, target} <- [{channel_post, channel}, {reply, channel}, {dm_post, dm}] do
      assert post.channel == target
      assert post.ts =~ ~r/\A\d+\.\d+\z/
      assert post.message["ts"] == post.ts
      assert post.message["text"] == @text
    end

    stored_post = stored_message!(token, channel, channel_post.ts)
    stored_dm_post = stored_message!(token, dm, dm_post.ts)

    assert reply.message["thread_ts"] == thread_ts
    refute Map.has_key?(reply.message, "subtype")

    assert %{"thread_ts" => ^thread_ts} =
             stored_reply = stored_reply!(token, channel, thread_ts, reply.ts)

    refute Map.has_key?(stored_reply, "subtype")

    # Slack keeps the text and renders the link markup as a link element.
    for stored <- [stored_post, stored_reply, stored_dm_post] do
      assert stored["text"] == @text
      assert link_urls(stored) == [@link]
    end

    # A broadcast reply also appears in the channel history.
    assert channel_history(token, channel, reply.ts) == []
  end

  # Both conversations exist, so opening them changes no messages.
  @tag env!([
         "SLACK_BOT_TOKEN",
         "SLACK_USER_TOKEN",
         "SLACK_SECOND_USER_ID",
         "SLACK_DM_CHANNEL_ID",
         "SLACK_MPIM_CHANNEL_ID"
       ])
  test "conversations.open opens the bot DM and the group DM and refuses an unknown user",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    authorizing_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])

    LiveSlack.record("conversations_open_im", fields: @conversation_fields)

    assert {:ok, %{channel: dm}} =
             Client.open_conversation(Map.put(@open_defaults, :users, [authorizing_user]), token)

    assert dm == env["SLACK_DM_CHANNEL_ID"]

    LiveSlack.record("conversations_open_mpim", fields: @conversation_fields)

    assert {:ok, %{channel: mpim, conversation: %{is_mpim: true}}} =
             Client.open_conversation(
               Map.put(@open_defaults, :users, [authorizing_user, env["SLACK_SECOND_USER_ID"]]),
               token
             )

    assert mpim == env["SLACK_MPIM_CHANNEL_ID"]

    LiveSlack.record("conversations_open_user_not_found")

    assert {:error, %Connect.Error.ProviderError{status: 200, reason: "user_not_found"}} =
             Client.open_conversation(Map.put(@open_defaults, :users, [@unknown_user]), token)
  end

  # Without return_im Slack answers with the DM's ID only; with it, Slack
  # returns the DM definition and its user. A separate test, so that recording
  # it leaves the other conversations.open recordings as they are.
  @tag env!(["SLACK_BOT_TOKEN", "SLACK_USER_TOKEN", "SLACK_DM_CHANNEL_ID"])
  test "conversations.open with return_im returns the bot DM and its user", %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    authorizing_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])
    dm = env["SLACK_DM_CHANNEL_ID"]
    params = Map.merge(@open_defaults, %{return_im: true, users: [authorizing_user]})

    LiveSlack.record("conversations_open_im_return_im", fields: @conversation_fields)

    assert {:ok, %{channel: ^dm, conversation: conversation}} =
             Client.open_conversation(params, token)

    assert %{id: ^dm, is_im: true, user: ^authorizing_user} = conversation
  end

  # Slack refuses the post, but a bot that rejoined the channel would post.
  @tag env!(["SLACK_BOT_TOKEN", "SLACK_NO_ACCESS_CHANNEL_ID"])
  @tag write!(:slack)
  test "chat.postMessage refuses a post to the channel the bot has left", %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    no_access = env["SLACK_NO_ACCESS_CHANNEL_ID"]

    LiveSlack.record("chat_post_message_not_in_channel")

    case Client.post_message(%{channel: no_access, text: @text, reply_broadcast: false}, token) do
      {:error, %Connect.Error.ProviderError{status: 200, reason: "not_in_channel"}} ->
        :ok

      {:ok, %{ts: ts}} ->
        LiveSlack.delete_message!(token, no_access, ts)
        flunk("the bot posted to #{no_access}, which it has left; the post was deleted")

      {:error, %Connect.Error.ProviderError{reason: reason}} ->
        flunk("expected not_in_channel from #{no_access}, got #{inspect(reason)}")
    end
  end

  # Posts through the action and deletes the post when the test exits.
  defp post!(token, input) do
    assert {:ok, %{ts: ts} = post} =
             LiveSlack.invoke("slack.message.post", input, token, ["chat:write"])

    LiveSlack.delete_on_exit(token, input.channel, ts)
    post
  end

  defp stored_message!(token, channel, ts) do
    assert [message] = channel_history(token, channel, ts)
    assert message["ts"] == ts
    message
  end

  defp channel_history(token, channel, ts) do
    %{status: 200, body: %{"ok" => true, "messages" => messages}} =
      LiveSlack.reference_request(token, :get, "conversations.history",
        params: [channel: channel, oldest: ts, latest: ts, inclusive: true, limit: 1]
      )

    messages
  end

  defp link_urls(%{"blocks" => blocks}) do
    for %{"type" => "rich_text", "elements" => sections} <- blocks,
        %{"elements" => elements} <- sections,
        %{"type" => "link", "url" => url} <- elements,
        do: url
  end

  defp link_urls(_message), do: []

  defp stored_reply!(token, channel, thread_ts, ts) do
    %{status: 200, body: %{"ok" => true, "messages" => messages}} =
      LiveSlack.reference_request(token, :get, "conversations.replies",
        params: [channel: channel, ts: thread_ts, oldest: ts, latest: ts, inclusive: true]
      )

    assert [reply] = Enum.filter(messages, &(&1["ts"] == ts))
    reply
  end
end
