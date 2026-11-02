defmodule Jido.Connect.Slack.ThreadRepliesLiveSmokeTest do
  @moduledoc """
  Live checks of `slack.thread.replies` against the Slack test workspace.

      MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  The action reads the prepared thread in pages of ten, once with the bot
  token and once with the user token, and follows `next_cursor` until
  `has_more` is false. Slack puts the parent first on every page and returns
  the newest replies on the first page, so the check drops the parent from
  each page and compares the replies as a sorted `ts` list. Both tokens must
  return the same pages, and each token's replies must equal one unpaged
  `conversations.replies` call made with Req outside the package. Every
  reply Slack returns must carry the parent's `ts` as `thread_ts`. The
  authorizing user, whom `auth.test` of the user token names, must have at
  least one reply among them, and the bot token must return each of these
  replies too. A page that carries the parent reports the parent's
  `reply_count` and `latest_reply`, although it holds only some of the
  replies. The package copies a page's `channel` and `thread_ts` from the
  request, so the check does not compare them.

  Each read prints the page count, the reply count and the SHA-256 prefix of
  the thread's `ts` list, parent first, then the replies in ascending order,
  one `ts` per line with a trailing newline; for the prepared thread that is
  the digest the workspace's seed check reported.

  With `JIDO_CONNECT_RECORD=1` the bot token's pages are recorded. The second
  test records two pages of two replies, a parent without replies and an
  unknown thread for the offline tests. `thread_replies_window.json` and
  `thread_replies_window.2.json` are the two pages of a read with `limit: 2`,
  `inclusive: true`, `oldest` set to the oldest reply of the prepared thread
  and `latest` to its fourth oldest reply. The fixtures keep no query; the
  bounds are the smallest and the largest reply `ts` across both files, and
  the test prints them. The parent without replies is the newest message
  before the prepared thread that has no subtype, thread, files or edit.
  Slack answers it with the parent alone and an unknown `ts` with
  `thread_not_found`, not with an empty page.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Slack.TestSupport.LiveSlack

  @scopes ["channels:history"]
  @page_limit 10

  # The prepared thread has three pages of ten; a longer chain means the
  # cursor does not advance.
  @max_pages 10

  # File previews hold file content, and file links name the workspace or
  # carry a public link key; no offline test needs them.
  @file_fields ["preview", "preview_highlight", "permalink", "permalink_public", "edit_link"]

  # Long before the test workspace existed; no message has this ts.
  @unknown_ts "1000000000.000100"

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_USER_TOKEN", "SLACK_PUBLIC_CHANNEL_ID", "SLACK_THREAD_TS"])
  test "the bot and the user token read the prepared thread over several pages with the same replies",
       %{env: env} do
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    parent = env["SLACK_THREAD_TS"]
    bot_token = env["SLACK_BOT_TOKEN"]
    user_token = env["SLACK_USER_TOKEN"]
    authorizing_user = LiveSlack.user_id!(user_token)

    bot_reference = reference_thread!(bot_token, channel, parent)
    user_reference = reference_thread!(user_token, channel, parent)
    report("reference conversations.replies with the bot token", bot_reference, parent)
    report("reference conversations.replies with the user token", user_reference, parent)

    record("thread_replies_pages")
    bot_pages = read_thread(:bot, bot_token, channel, parent)

    LiveSlack.skip_recording()
    user_pages = read_thread(:user, user_token, channel, parent)

    assert length(bot_pages) >= 2

    assert Enum.map(bot_pages, &page_ts(&1, parent)) ==
             Enum.map(user_pages, &page_ts(&1, parent))

    bot_replies = Enum.flat_map(bot_pages, &replies(&1, parent))
    user_replies = Enum.flat_map(user_pages, &replies(&1, parent))

    assert sorted_ts(bot_replies) == sorted_ts(replies(bot_reference, parent))
    assert sorted_ts(user_replies) == sorted_ts(replies(user_reference, parent))
    assert Enum.all?(bot_replies ++ user_replies, &(&1.thread_ts == parent))

    report("slack.thread.replies with the bot token", bot_pages, bot_replies, parent)
    report("slack.thread.replies with the user token", user_pages, user_replies, parent)

    authorizing_replies =
      user_replies
      |> Enum.filter(&(&1[:user] == authorizing_user and &1[:bot_id] == nil))
      |> sorted_ts()

    assert authorizing_replies != [], "no reply of the authorizing user #{authorizing_user}"
    assert authorizing_replies -- sorted_ts(bot_replies) == []

    IO.puts(
      "live_smoke slack: replies of the authorizing user #{authorizing_user}: " <>
        Enum.join(authorizing_replies, ", ")
    )

    root = root!(bot_reference, parent)

    for page <- bot_pages ++ user_pages, match?([%{ts: ^parent} | _], page.messages) do
      assert {page.reply_count, page.latest_reply} == {root["reply_count"], root["latest_reply"]}
    end
  end

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_PUBLIC_CHANNEL_ID", "SLACK_THREAD_TS"])
  test "records two pages of two replies, a parent without replies and an unknown thread",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    parent = env["SLACK_THREAD_TS"]
    thread = reference_thread!(token, channel, parent)
    root = root!(thread, parent)
    lone_ts = lone_message_ts!(token, channel, parent)

    # The four oldest replies: two full pages, and the first page ends before
    # the newest reply, so the parent's reply_count and latest_reply differ
    # from what the page holds.
    window =
      thread
      |> replies(parent)
      |> sorted_ts()
      |> Enum.take(4)

    assert [oldest, _second, _third, latest] = window

    params = %{
      channel: channel,
      ts: parent,
      conversation_type: "public_channel",
      limit: 2,
      oldest: oldest,
      latest: latest,
      inclusive: true
    }

    record("thread_replies_window")

    assert {:ok, %{has_more: true, next_cursor: cursor} = first} =
             thread_replies(:bot, token, params)

    assert cursor != ""

    assert {:ok, %{has_more: false} = second} =
             thread_replies(:bot, token, Map.put(params, :cursor, cursor))

    assert sorted_ts(replies(first, parent) ++ replies(second, parent)) == window
    assert {first.reply_count, first.latest_reply} == {root["reply_count"], root["latest_reply"]}

    IO.puts("live_smoke slack: window of limit 2: oldest #{oldest}, latest #{latest}, inclusive")

    record("thread_replies_no_replies")

    assert {:ok, %{messages: [%{ts: ^lone_ts}], reply_count: 0, has_more: false}} =
             thread_replies(:bot, token, %{
               channel: channel,
               ts: lone_ts,
               conversation_type: "public_channel"
             })

    IO.puts("live_smoke slack: parent without replies: #{lone_ts}")
    record("thread_replies_thread_not_found")

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "thread_not_found"
            }} =
             thread_replies(:bot, token, %{
               channel: channel,
               ts: @unknown_ts,
               conversation_type: "public_channel"
             })
  end

  defp record(name), do: LiveSlack.record(name, fields: @file_fields)

  defp thread_replies(profile, token, input) do
    LiveSlack.invoke("slack.thread.replies", input, token, @scopes, profile)
  end

  # Follows next_cursor from the first page until has_more is false.
  defp read_thread(profile, token, channel, parent) do
    params = %{
      channel: channel,
      ts: parent,
      conversation_type: "public_channel",
      limit: @page_limit
    }

    read_pages(profile, token, params, nil, [])
  end

  defp read_pages(profile, token, params, cursor, pages) do
    assert length(pages) < @max_pages, "#{profile} token: more than #{@max_pages} pages"
    input = if cursor, do: Map.put(params, :cursor, cursor), else: params

    assert {:ok, page} = thread_replies(profile, token, input)

    case page do
      %{has_more: true, next_cursor: next} when next != "" ->
        read_pages(profile, token, params, next, [page | pages])

      %{has_more: false} ->
        Enum.reverse([page | pages])
    end
  end

  defp replies(%{messages: messages}, parent), do: replies(messages, parent)
  defp replies(messages, parent), do: Enum.reject(messages, &(ts(&1) == parent))

  defp root!(messages, parent) do
    assert [root] = Enum.filter(messages, &(ts(&1) == parent))
    root
  end

  defp page_ts(page, parent), do: page |> replies(parent) |> Enum.map(&ts/1)
  defp sorted_ts(messages), do: messages |> Enum.map(&ts/1) |> Enum.sort()

  defp ts(%{"ts" => ts}), do: ts
  defp ts(%{ts: ts}), do: ts

  defp report(label, reference, parent) do
    replies = replies(reference, parent)

    IO.puts(
      "live_smoke slack: #{label}: #{length(replies)} replies, " <>
        "ts list sha256 #{digest(parent, replies)}"
    )
  end

  defp report(label, pages, replies, parent) do
    IO.puts(
      "live_smoke slack: #{label}: #{length(replies)} replies of #{parent} " <>
        "in #{length(pages)} pages of #{@page_limit}, ts list sha256 #{digest(parent, replies)}"
    )
  end

  defp digest(parent, replies) do
    [parent | sorted_ts(replies)]
    |> Enum.map_join(&(&1 <> "\n"))
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp reference_thread!(token, channel, parent) do
    assert %{
             status: 200,
             body: %{"ok" => true, "has_more" => false, "messages" => messages}
           } =
             LiveSlack.reference_request(token, :get, "conversations.replies",
               params: [channel: channel, ts: parent, limit: 1000]
             )

    messages
  end

  # The newest message before the prepared thread that has no subtype,
  # thread, files or edit. Posts after the thread do not change the choice,
  # so a new recording keeps the same parent without replies.
  defp lone_message_ts!(token, channel, parent) do
    assert %{status: 200, body: %{"ok" => true, "messages" => messages}} =
             LiveSlack.reference_request(token, :get, "conversations.history",
               params: [channel: channel, latest: parent, limit: 100]
             )

    assert %{"ts" => ts} =
             Enum.find(messages, fn message ->
               not Enum.any?(
                 ["subtype", "thread_ts", "reply_count", "files", "edited"],
                 &Map.has_key?(message, &1)
               )
             end)

    ts
  end
end
