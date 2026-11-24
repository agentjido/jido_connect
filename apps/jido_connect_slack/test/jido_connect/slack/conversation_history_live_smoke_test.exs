defmodule Jido.Connect.Slack.ConversationHistoryLiveSmokeTest do
  @moduledoc """
  Live checks of Slack conversation history against the Slack test workspace.

      MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  The action reads each conversation in two pages. A single unpaged
  `conversations.history` call, made with Req outside the package, is the
  reference: both pages together must return the same `ts` order, the same
  author IDs and the same SHA-256 digest of every text. The checks on authors,
  text length, files and edits restate the expectations of the workspace's
  seed check. `auth.test` supplies the bot user and the authorizing user.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Slack.Client
  alias Jido.Connect.Slack.TestSupport.LiveSlack

  @history_scopes ["channels:history", "groups:history", "im:history", "mpim:history"]

  # File previews hold file content, and file links name the workspace or
  # carry a public link key; no offline test needs them.
  @file_fields ["preview", "preview_highlight", "permalink", "permalink_public", "edit_link"]

  @conversations [
    {"public_channel", "SLACK_PUBLIC_CHANNEL_ID"},
    {"private_channel", "SLACK_PRIVATE_CHANNEL_ID"},
    {"im", "SLACK_DM_CHANNEL_ID"},
    {"mpim", "SLACK_MPIM_CHANNEL_ID"}
  ]

  @matrix_env [
                "SLACK_BOT_TOKEN",
                "SLACK_USER_TOKEN",
                "SLACK_NO_ACCESS_CHANNEL_ID",
                "SLACK_SECOND_USER_ID"
              ] ++ Enum.map(@conversations, &elem(&1, 1))

  @tag env!(@matrix_env)
  test "the bot token reads every conversation type in two pages and is denied a channel it left",
       %{env: env} do
    people = people(env)
    token = env["SLACK_BOT_TOKEN"]

    for {type, variable} <- @conversations do
      messages = assert_two_pages_match(:bot, token, env[variable], type)
      assert_prepared(type, messages, people)
    end

    assert {:error, %Connect.Error.ProviderError{provider: :slack, reason: "not_in_channel"}} =
             history(:bot, token, %{
               channel: env["SLACK_NO_ACCESS_CHANNEL_ID"],
               conversation_type: "public_channel"
             })
  end

  @tag env!(@matrix_env)
  test "the user token reads every conversation type in two pages and the channel the bot left",
       %{env: env} do
    people = people(env)
    token = env["SLACK_USER_TOKEN"]

    for {type, variable} <- @conversations do
      messages = assert_two_pages_match(:user, token, env[variable], type)
      assert_prepared(type, messages, people)
    end

    messages =
      assert_two_pages_match(:user, token, env["SLACK_NO_ACCESS_CHANNEL_ID"], "public_channel")

    assert count(messages, &human_by?(&1, people.authorizing_user)) >= 1
  end

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_PUBLIC_CHANNEL_ID", "SLACK_NO_ACCESS_CHANNEL_ID"])
  test "records a full and a short page, an empty page and a denied read", %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    reference = reference_history!(token, channel)
    limit = page_limit(reference)
    params = %{channel: channel, conversation_type: "public_channel", limit: limit}

    record("conversation_history_pages")

    assert {:ok, %{has_more: true, next_cursor: cursor} = full} =
             Client.get_conversation_history(params, token)

    assert length(full.messages) == limit
    assert cursor != ""

    assert {:ok, %{has_more: false} = short} =
             Client.get_conversation_history(Map.put(params, :cursor, cursor), token)

    assert length(short.messages) == length(reference) - limit

    record("conversation_history_empty")

    assert {:ok, %{messages: [], has_more: false}} =
             Client.get_conversation_history(Map.put(params, :latest, "1000000000.000000"), token)

    record("conversation_history_not_in_channel")

    assert {:error, %Connect.Error.ProviderError{reason: "not_in_channel"}} =
             Client.get_conversation_history(
               %{channel: env["SLACK_NO_ACCESS_CHANNEL_ID"], conversation_type: "public_channel"},
               token
             )
  end

  # The prepared messages carry no legacy attachments and no empty text, so
  # this test posts one such bot message, records the page and deletes it.
  @tag env!(["SLACK_BOT_TOKEN", "SLACK_PUBLIC_CHANNEL_ID"])
  @tag write!(:slack)
  test "records a bot message with attachments and empty text", %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]

    ts =
      LiveSlack.post_reference!(token, %{
        channel: channel,
        text: "",
        attachments: [
          %{
            fallback: "Live smoke attachment",
            title: "Live smoke attachment",
            text: "Legacy attachment posted by the conversation history live test.",
            fields: [%{title: "Kind", value: "attachment", short: true}]
          }
        ]
      })

    LiveSlack.delete_on_exit(token, channel, ts)

    record("conversation_history_attachments")

    assert {:ok, %{messages: [message], has_more: false}} =
             Client.get_conversation_history(
               %{
                 channel: channel,
                 conversation_type: "public_channel",
                 oldest: ts,
                 latest: ts,
                 inclusive: true,
                 limit: 1
               },
               token
             )

    assert message.ts == ts
    assert message.text == ""
    assert [%{"fields" => [%{"title" => "Kind"}]}] = message.attachments
  end

  defp record(name), do: LiveSlack.record(name, fields: @file_fields)

  defp assert_two_pages_match(profile, token, channel, type) do
    reference = reference_history!(token, channel)
    limit = page_limit(reference)
    params = %{channel: channel, conversation_type: type, limit: limit}

    assert {:ok, %{has_more: true, next_cursor: cursor} = first} = history(profile, token, params)
    assert cursor != ""
    assert length(first.messages) == limit

    assert {:ok, %{has_more: false} = second} =
             history(profile, token, Map.put(params, :cursor, cursor))

    messages = first.messages ++ second.messages

    assert Enum.map(messages, &identity/1) == Enum.map(reference, &identity/1),
           "#{type} #{channel} with the #{profile} token differs from the reference"

    assert Enum.all?(messages, &(&1.channel == channel and &1.conversation_type == type))
    messages
  end

  defp assert_prepared(type, messages, people) do
    assert count(messages, &bot?(&1, people.bot_user)) >= 2, "#{type}: bot messages"

    assert count(messages, &human_by?(&1, people.authorizing_user)) >= 1,
           "#{type}: authorizing user"

    assert Enum.any?(messages, &(byte_size(&1.text || "") > 512)), "#{type}: text over 512 bytes"

    case type do
      "public_channel" ->
        assert count(messages, &human_by?(&1, people.second_user)) >= 1
        assert count(messages, &(&1.files not in [nil, []])) >= 2
        assert count(messages, &(&1.edited != nil)) >= 1
        assert count(messages, &(&1.thread_ts != nil)) >= 1

      "mpim" ->
        assert count(messages, &human_by?(&1, people.second_user)) >= 1

      _other ->
        :ok
    end
  end

  defp history(profile, token, params) do
    LiveSlack.invoke("slack.conversation.history", params, token, @history_scopes, profile)
  end

  defp people(env) do
    %{
      bot_user: LiveSlack.user_id!(env["SLACK_BOT_TOKEN"]),
      authorizing_user: LiveSlack.user_id!(env["SLACK_USER_TOKEN"]),
      second_user: env["SLACK_SECOND_USER_ID"]
    }
  end

  # Two pages: the first full, the second shorter. Needs three messages.
  defp page_limit(reference) do
    assert length(reference) >= 3
    div(length(reference), 2) + 1
  end

  defp identity(%{"ts" => ts} = message),
    do: {ts, message["user"], message["bot_id"], message["app_id"], digest(message["text"])}

  defp identity(message),
    do: {message.ts, message.user, message.bot_id, message.app_id, digest(message.text)}

  defp digest(nil), do: nil
  defp digest(text), do: :sha256 |> :crypto.hash(text) |> Base.encode16(case: :lower)

  defp bot?(message, bot_user), do: message.bot_id != nil or message.user == bot_user

  # Human messages as the seed check counts them: no bot and no notice subtype.
  defp human_by?(message, user) do
    message.user == user and message.bot_id == nil and
      message.subtype in [nil, "file_share", "thread_broadcast"]
  end

  defp count(messages, fun), do: Enum.count(messages, fun)

  defp reference_history!(token, channel) do
    %{status: 200, body: %{"ok" => true, "has_more" => false, "messages" => messages}} =
      LiveSlack.reference_request(token, :get, "conversations.history",
        params: [channel: channel, limit: 100]
      )

    messages
  end
end
