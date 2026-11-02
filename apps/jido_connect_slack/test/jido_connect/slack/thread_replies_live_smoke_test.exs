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
  `thread_not_found`, not with an empty page. The third test records such a
  parent in the private channel, read with `groups:history`.

  The write test records `thread_replies_message_kinds.json`, one page of
  the prepared thread that holds a human reply, a bot reply, a reply over 512
  bytes, a reply with a file and a reply with a reaction. The prepared thread
  has neither files nor reactions, and the user token cannot post, so the bot
  adds two replies for the run: one with an uploaded text file, and one with
  a legacy attachment and a reaction. The page is read with `oldest` set to
  the newest prepared reply over 512 bytes and `inclusive: true`, so it runs
  from that reply through the authorizing user's reply to the two new ones.
  The test recognizes its replies by their texts and the file name. It does
  not write while the thread still holds such a reply from an earlier run,
  and names its `ts`. When the test exits, it deletes both replies, which
  removes the reaction, then the file, and checks that the thread holds the
  prepared replies again with the parent's `reply_count` and `latest_reply`
  from before the run. One exit callback runs these steps and reports all
  their failures together.
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

  @file_name "thread-replies-live-test.txt"
  @file_title "Thread replies live test file"
  @file_content "Text file uploaded by the thread replies live test.\n"
  @file_comment "Thread replies live test: a bot reply with a file."
  @reaction_text "Thread replies live test: a bot reply with an attachment and a reaction."
  @reaction "white_check_mark"

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
    lone_ts = lone_message_ts!(token, channel, latest: parent)

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

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_PRIVATE_CHANNEL_ID"])
  test "records a parent without replies in the private channel, read with groups:history",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PRIVATE_CHANNEL_ID"]
    lone_ts = lone_message_ts!(token, channel, [])

    record("thread_replies_private_no_replies")

    assert {:ok, %{messages: [%{ts: ^lone_ts}], reply_count: 0, has_more: false}} =
             LiveSlack.invoke(
               "slack.thread.replies",
               %{channel: channel, ts: lone_ts, conversation_type: "private_channel"},
               token,
               ["groups:history"]
             )

    IO.puts("live_smoke slack: private channel parent without replies: #{lone_ts}")
  end

  @tag env!(["SLACK_BOT_TOKEN", "SLACK_USER_TOKEN", "SLACK_PUBLIC_CHANNEL_ID", "SLACK_THREAD_TS"])
  @tag write!(:slack)
  test "records a page of the prepared thread with human, bot, long, file and reaction replies",
       %{env: env} do
    token = env["SLACK_BOT_TOKEN"]
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    parent = env["SLACK_THREAD_TS"]
    authorizing_user = LiveSlack.user_id!(env["SLACK_USER_TOKEN"])

    prepared = reference_thread!(token, channel, parent)
    refute_earlier_run!(prepared, parent)

    assert long_ts =
             prepared
             |> replies(parent)
             |> Enum.filter(&(byte_size(&1["text"] || "") > 512))
             |> sorted_ts()
             |> List.last()

    # Every write of the run follows the upload URL.
    {upload_url, file_id} = file_upload_url!(token)
    on_exit(fn -> clean_up!(token, channel, parent, prepared, file_id) end)

    file_ts = post_file_reply!(token, channel, parent, upload_url, file_id)
    reaction_ts = post_reaction_reply!(token, channel, parent)

    record("thread_replies_message_kinds")

    assert {:ok, %{has_more: false} = page} =
             thread_replies(:bot, token, %{
               channel: channel,
               ts: parent,
               conversation_type: "public_channel",
               oldest: long_ts,
               inclusive: true
             })

    LiveSlack.skip_recording()

    assert [%{ts: ^parent} | page_replies] = page.messages

    expected_ts =
      prepared
      |> replies(parent)
      |> sorted_ts()
      |> Enum.drop_while(&(&1 != long_ts))
      |> Kernel.++([file_ts, reaction_ts])
      |> Enum.sort()

    assert sorted_ts(page_replies) == expected_ts

    assert Enum.any?(page_replies, &(&1[:user] == authorizing_user and &1[:bot_id] == nil))

    assert Enum.any?(
             page_replies,
             &(&1[:bot_id] != nil and &1[:files] == nil and &1[:reactions] == nil)
           )

    assert %{text: long_text} = Enum.find(page_replies, &(&1.ts == long_ts))
    assert byte_size(long_text) > 512
    assert %{files: [%{"id" => ^file_id}]} = Enum.find(page_replies, &(&1.ts == file_ts))

    assert %{reactions: [%{"name" => @reaction}], attachments: [_attachment]} =
             Enum.find(page_replies, &(&1.ts == reaction_ts))

    IO.puts(
      "live_smoke slack: page of #{length(page_replies)} replies from #{long_ts}, " <>
        "file reply #{file_ts} with #{file_id}, reaction reply #{reaction_ts}"
    )
  end

  defp record(name), do: LiveSlack.record(name, fields: @file_fields)

  # Starts the external upload flow and returns the upload URL and the file
  # ID.
  defp file_upload_url!(token) do
    assert %{status: 200, body: %{"ok" => true, "upload_url" => url, "file_id" => file_id}} =
             LiveSlack.reference_request(token, :post, "files.getUploadURLExternal",
               form: [filename: @file_name, length: byte_size(@file_content)]
             )

    {url, file_id}
  end

  # Uploads the text file, shares it into the thread and returns the reply's
  # ts.
  defp post_file_reply!(token, channel, parent, url, file_id) do
    assert %{status: 200} = Req.post!(url, body: @file_content, retry: false)

    assert %{status: 200, body: %{"ok" => true}} =
             LiveSlack.reference_request(token, :post, "files.completeUploadExternal",
               form: [
                 files: Jason.encode!([%{id: file_id, title: @file_title}]),
                 channel_id: channel,
                 thread_ts: parent,
                 initial_comment: @file_comment
               ]
             )

    await_file_reply!(token, channel, parent, file_id, 10)
  end

  # Slack shares an uploaded file asynchronously.
  defp await_file_reply!(token, channel, parent, file_id, attempts) do
    reply =
      token
      |> reference_thread!(channel, parent)
      |> Enum.find(fn message ->
        Enum.any?(Map.get(message, "files", []), &(&1["id"] == file_id))
      end)

    case reply do
      %{"ts" => ts} ->
        ts

      nil when attempts > 1 ->
        Process.sleep(1_000)
        await_file_reply!(token, channel, parent, file_id, attempts - 1)

      nil ->
        flunk("the reply with #{file_id} did not appear in the thread #{parent}")
    end
  end

  # Posts a reply with a legacy attachment and adds a reaction to it.
  defp post_reaction_reply!(token, channel, parent) do
    ts =
      LiveSlack.post_reference!(token, %{
        channel: channel,
        thread_ts: parent,
        text: @reaction_text,
        attachments: [
          %{
            fallback: "Thread replies live test attachment",
            title: "Thread replies live test attachment",
            text: "Legacy attachment posted by the thread replies live test."
          }
        ]
      })

    assert %{status: 200, body: %{"ok" => true}} =
             LiveSlack.reference_request(token, :post, "reactions.add",
               json: %{channel: channel, timestamp: ts, name: @reaction}
             )

    ts
  end

  # A reply that an earlier run left would count as prepared, and the check
  # after cleanup would accept it.
  defp refute_earlier_run!(prepared, parent) do
    left = prepared |> Enum.filter(&run_reply?/1) |> sorted_ts()

    assert left == [],
           "the thread #{parent} holds replies of an earlier write run: " <>
             "#{Enum.join(left, ", ")}; delete them before the next live run"
  end

  defp run_reply?(message) do
    message["text"] in [@file_comment, @reaction_text] or
      Enum.any?(Map.get(message, "files", []), &(&1["name"] == @file_name))
  end

  # Runs when the write test exits. It deletes the run's replies, which
  # removes the reaction with its reply, then the file, and checks the thread.
  # The replies are found by their text or file, so the file reply goes too
  # when it appeared only after `await_file_reply!/5` gave up. ExUnit reports
  # only the first failing exit callback, so every step runs and the failures
  # are raised together. If the first read of the thread fails, nothing is
  # deleted, and the next run names the replies left.
  defp clean_up!(token, channel, parent, prepared, file_id) do
    reply_deletes =
      for %{"ts" => ts} <- Enum.filter(reference_thread!(token, channel, parent), &run_reply?/1) do
        fn -> LiveSlack.delete_message!(token, channel, ts) end
      end

    steps =
      reply_deletes ++
        [
          fn -> LiveSlack.delete_file!(token, file_id) end,
          fn -> assert_thread_restored!(token, channel, parent, prepared) end
        ]

    case Enum.flat_map(steps, &failure/1) do
      [] -> :ok
      errors -> raise ExUnit.MultiError, errors: errors
    end
  end

  defp failure(step) do
    step.()
    []
  rescue
    error -> [{:error, error, __STACKTRACE__}]
  end

  # The thread must hold the prepared replies again, and the parent must
  # report the reply count and latest reply from before the run.
  defp assert_thread_restored!(token, channel, parent, prepared) do
    thread = reference_thread!(token, channel, parent)
    root = root!(thread, parent)
    prepared_root = root!(prepared, parent)

    assert sorted_ts(thread) == sorted_ts(prepared),
           "the thread #{parent} differs from before the run: " <>
             "left #{inspect(sorted_ts(thread) -- sorted_ts(prepared))}, " <>
             "missing #{inspect(sorted_ts(prepared) -- sorted_ts(thread))}"

    assert {root["reply_count"], root["latest_reply"]} ==
             {prepared_root["reply_count"], prepared_root["latest_reply"]}

    report("thread after cleanup", thread, parent)
  end

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

  # The newest message, before `latest` when given, that has no subtype,
  # thread, files or edit. In the public channel the prepared thread is
  # `latest`, so posts after it do not change the choice and a new recording
  # keeps the same parent without replies.
  defp lone_message_ts!(token, channel, history_params) do
    assert %{status: 200, body: %{"ok" => true, "messages" => messages}} =
             LiveSlack.reference_request(token, :get, "conversations.history",
               params: [channel: channel, limit: 100] ++ history_params
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
