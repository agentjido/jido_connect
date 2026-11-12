defmodule Jido.Connect.Slack.MessageIngressLiveSmokeTest do
  @moduledoc """
  Live checks of Events API message ingress against the Slack test workspace.

      MIX_ENV=test mix do --app jido_connect_slack test --only live_smoke

  A person in the Slack client posted the deliveries below while the demo
  host ran in capture mode (`docs/live_smoke_tests.md`), so they lie in
  `SLACK_CAPTURE_DIR`. Each text starts with a label from the capture
  checklist, such as `plain-public`; a message that mentions the app starts
  with the mention, followed by its label. The test finds each delivery by
  event type, subtype, conversation and label, never by file name, and takes
  the earliest first delivery: Slack's retries carry `x-slack-retry-num`.

  The first test replays each message delivery raw through
  `Jido.Connect.Slack.Webhook.verify_delivery/4` with `SLACK_SIGNING_SECRET`
  and compares the normalized signal with the message that the bot token
  reads through `conversations.history`, or `conversations.replies` for a
  reply, with Req outside the package. The channel must be the configured
  conversation, and `ts`, `user`, `text` and `thread_ts` must match Slack's
  stored message. A message that has become a thread parent since it was
  posted is stored with its own `ts` as `thread_ts`; its delivery had none.
  The subtype must be the delivery's own. Slack's history omits
  `file_share`, but keeps `thread_broadcast`, so the test checks the stored
  subtype separately. For a message shared into the bot DM, each entry of
  `shared_messages` must match the source message read from its channel.

  The second test replays messages that were posted, edited and deleted: one
  per conversation class and a thread reply, each edited twice by the person
  who wrote it, and two bot messages that the bot edited with `chat.update`,
  once to an empty text beside an attachment, and deleted with
  `chat.delete`. It finds the post by its label, and its edits and deletion
  by the post's `ts` in `message.ts` and `deleted_ts`. Each edit and the
  deletion must verify raw and yield a change signal whose `ts` is the
  post's `ts`, apart from the notification's own `ts`, with an event ID of
  its own. The bot token must no longer find the post in
  `conversations.history`, or for the reply in `conversations.replies`.
  `message_changed` deliveries without `message.edited`, a thread parent's
  new reply count, a broadcast reply's update of its thread root and a link
  unfurl, must verify without a signal.

  The third test replays the deletions of thread parents with replies in the
  public channel, which the bot posted, replied to and deleted with
  `chat.delete`, one of them after an edit. Slack reports such a deletion as
  a `message_changed` whose `message` is a tombstone, and the removal of the
  tombstone after the last reply was deleted as a `message_deleted` whose
  `previous_message` is the tombstone. The test finds each tombstone by its
  subtype and the parent by its `ts`. The tombstone must yield a deletion
  signal with the parent's `ts` and author and no edit, the removal a
  deletion signal with the same `ts`, no author and an event ID of its own,
  and the bot token must no longer find the parent.

  With `JIDO_CONNECT_RECORD=1` each delivery the tests use becomes the
  fixture `test/fixtures/slack/captured/<name>.json`, sanitized and signed
  again with `LiveSmoke.replay_secret/0`; the posts that were edited stay
  out. Message texts stay, because the offline tests check text beyond 512
  bytes; they are checklist test data. File previews and file links, and the
  share fields that carry the workspace URL, the author's handle or avatar,
  become placeholders. The unfurl links to the workspace, so all its texts
  and links become placeholders as well.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Slack.TestSupport.LiveSlack
  alias Jido.Connect.Slack.Webhook
  alias Jido.Connect.WebhookDelivery

  @env [
    "SLACK_BOT_TOKEN",
    "SLACK_SIGNING_SECRET",
    "SLACK_CAPTURE_DIR",
    "SLACK_PUBLIC_CHANNEL_ID",
    "SLACK_PRIVATE_CHANNEL_ID",
    "SLACK_DM_CHANNEL_ID",
    "SLACK_MPIM_CHANNEL_ID"
  ]

  # File previews hold file content, and file links name the workspace or
  # carry a public link key, as in the recordings of `slack.thread.replies`.
  # A share's `fallback` and `author_name` hold the author's handle,
  # `author_icon` an avatar URL, and `author_link` and `from_url` the
  # workspace URL.
  @capture_fields ~w(preview preview_highlight permalink permalink_public edit_link
                     fallback author_icon author_link from_url)
  @capture_name_keys ~w(author_name author_subname)

  # `stored_subtype` is the subtype of the message in Slack's history.
  @message_kinds [
    %{
      kind: :public_message,
      fixture: "message_public",
      type: "message",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "plain-public"
    },
    %{
      kind: :private_message,
      fixture: "message_private",
      type: "message",
      channel: "SLACK_PRIVATE_CHANNEL_ID",
      label: "plain-private"
    },
    %{
      kind: :direct_message,
      fixture: "message_im",
      type: "message",
      channel: "SLACK_DM_CHANNEL_ID",
      label: "dm"
    },
    %{
      kind: :group_direct_message,
      fixture: "message_mpim",
      type: "message",
      channel: "SLACK_MPIM_CHANNEL_ID",
      label: "group-dm"
    },
    %{
      kind: :thread_reply,
      fixture: "message_thread_reply",
      type: "message",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "thread-reply"
    },
    %{
      kind: :thread_broadcast,
      fixture: "message_thread_broadcast",
      type: "message",
      subtype: "thread_broadcast",
      stored_subtype: "thread_broadcast",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "broadcast-reply"
    },
    %{
      kind: :file_share,
      fixture: "message_file_share",
      type: "message",
      subtype: "file_share",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "file-share"
    },
    %{
      kind: :mention_message,
      fixture: "message_mention",
      type: "message",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "app-mention"
    },
    %{
      kind: :app_mention,
      fixture: "app_mention",
      type: "app_mention",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "app-mention"
    },
    %{
      kind: :shared_public_message,
      fixture: "message_im_shared_public",
      type: "message",
      channel: "SLACK_DM_CHANNEL_ID",
      label_at: :shared_message,
      label: "plain-public",
      source_channel: "SLACK_PUBLIC_CHANNEL_ID"
    },
    %{
      kind: :shared_private_message,
      fixture: "message_im_shared_private",
      type: "message",
      channel: "SLACK_DM_CHANNEL_ID",
      label_at: :shared_message,
      label: "plain-private",
      source_channel: "SLACK_PRIVATE_CHANNEL_ID"
    }
  ]

  # Posts that were edited `edits` times and then deleted. `family` is the
  # trigger family of the conversation, and `name` the suffix of the
  # fixtures: message_changed_<name>, message_changed_<name>_2 and
  # message_deleted_<name>.
  @change_sequences [
    %{
      name: "public",
      family: "message.channels",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "edit-public",
      edits: 2
    },
    %{
      name: "private",
      family: "message.groups",
      channel: "SLACK_PRIVATE_CHANNEL_ID",
      label: "edit-private",
      edits: 2
    },
    %{
      name: "im",
      family: "message.im",
      channel: "SLACK_DM_CHANNEL_ID",
      label: "edit-dm",
      edits: 2
    },
    %{
      name: "mpim",
      family: "message.mpim",
      channel: "SLACK_MPIM_CHANNEL_ID",
      label: "edit-group-dm",
      edits: 2
    },
    %{
      name: "thread_reply",
      family: "message.channels",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "edit-thread",
      edits: 2
    },
    %{
      name: "bot",
      family: "message.channels",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "edit-bot",
      edits: 2
    },
    %{
      name: "bot_empty_text",
      family: "message.channels",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label: "edit-bot-empty",
      edits: 1
    }
  ]

  # `message_changed` deliveries without `message.edited`. The unfurl came
  # through the app's user events from a DM of the authorizing user.
  @unedited_changes [
    %{kind: :thread_parent, fixture: "message_changed_thread_parent", family: "message.channels"},
    %{
      kind: :broadcast_root,
      fixture: "message_changed_broadcast_root",
      family: "message.channels"
    },
    %{kind: :unfurl, fixture: "message_changed_unfurl", family: "message.im"}
  ]

  @unfurl_fields ~w(text url original_url footer)

  @tag env!(@env)
  test "captured message deliveries normalize to the messages Slack stores", %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]
    token = env["SLACK_BOT_TOKEN"]
    deliveries = deliveries!(env, @message_kinds)

    if LiveSmoke.recording?() do
      for {spec, capture} <- deliveries do
        LiveSmoke.write_capture!(capture, :slack, spec.fixture,
          secret: secret,
          fields: @capture_fields,
          name_keys: @capture_name_keys
        )
      end
    end

    for {spec, capture} <- deliveries do
      event = event(capture)

      assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
               LiveSmoke.replay(capture, webhook: Webhook, secret: secret),
             "#{spec.kind} does not normalize"

      {method, stored} = stored_message!(token, event["channel"], event["ts"], event["thread_ts"])

      assert signal.channel == env[spec.channel], "#{spec.kind} channel"
      assert signal.ts == stored["ts"], "#{spec.kind} ts"
      assert signal.user == stored["user"], "#{spec.kind} user"
      assert Map.get(signal, :text, "") == stored["text"], "#{spec.kind} text"
      assert Map.get(signal, :thread_ts) == reply_thread_ts(stored), "#{spec.kind} thread_ts"
      assert Map.get(signal, :subtype) == spec[:subtype], "#{spec.kind} subtype"
      assert stored["subtype"] == spec[:stored_subtype], "#{spec.kind} stored subtype"

      assert_kind(spec, signal, stored, token, env)

      IO.puts(
        "live_smoke slack: #{spec.kind} #{event["type"]} #{signal.channel} #{signal.ts} " <>
          "matches conversations.#{method}"
      )
    end
  end

  @tag env!(@env)
  test "captured edits and deletions keep the source ts with distinct event IDs", %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]
    token = env["SLACK_BOT_TOKEN"]
    captures = first_deliveries!(env)
    sequences = for spec <- @change_sequences, do: {spec, change_sequence!(captures, spec, env)}
    unedited = for spec <- @unedited_changes, do: {spec, unedited_change!(captures, spec, env)}

    if LiveSmoke.recording?() do
      for {spec, %{edits: edits, deletion: deletion}} <- sequences do
        for {capture, n} <- Enum.with_index(edits, 1) do
          suffix = if n == 1, do: "", else: "_#{n}"
          write_change!(capture, "message_changed_#{spec.name}#{suffix}", secret, [])
        end

        write_change!(deletion, "message_deleted_#{spec.name}", secret, [])
      end

      for {spec, capture} <- unedited do
        extra = if spec.kind == :unfurl, do: @unfurl_fields, else: []
        write_change!(capture, spec.fixture, secret, extra)
      end
    end

    for {spec, sequence} <- sequences do
      assert_change_sequence(spec, sequence, secret, token, env)
    end

    for {spec, capture} <- unedited do
      payload = Jason.decode!(capture["body"])
      event = payload["event"]

      assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: nil}} =
               LiveSmoke.replay(capture, webhook: Webhook, secret: secret),
             "#{spec.kind} yields a signal"

      for result <- [
            Webhook.normalize_event(payload),
            Webhook.normalize_signal("#{spec.family}.changed", payload)
          ] do
        assert {:error, %ProviderError{reason: :not_an_edit}} = result, "#{spec.kind}"
      end

      IO.puts(
        "live_smoke slack: #{spec.kind} #{event["channel"]} #{event["message"]["ts"]} " <>
          "#{payload["event_id"]} is no edit"
      )
    end
  end

  @tag env!(@env)
  test "captured deletions of thread parents with replies yield deletion signals", %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]
    token = env["SLACK_BOT_TOKEN"]
    sequences = tombstone_sequences!(first_deliveries!(env), env)

    plain = Enum.find(sequences, &(not edited_parent?(&1))) || flunk("no unedited parent")
    edited = Enum.find(sequences, &edited_parent?/1) || flunk("no edited parent")
    assert plain.removal, "no removal of the tombstone #{plain.ts}"

    if LiveSmoke.recording?() do
      write_change!(plain.tombstone, "message_changed_tombstone", secret, [])
      write_change!(plain.removal, "message_deleted_tombstone", secret, [])
      write_change!(edited.tombstone, "message_changed_tombstone_edited", secret, [])
    end

    for sequence <- sequences do
      assert_tombstone_sequence(sequence, secret, token, env)
    end
  end

  defp assert_change_sequence(spec, sequence, secret, token, env) do
    %{original: original, edits: edits, deletion: deletion} = sequence

    assert {:ok, %WebhookDelivery{normalized_signal: %{} = posted}} =
             LiveSmoke.replay(original, webhook: Webhook, secret: secret),
           "#{spec.label} post does not normalize"

    signals =
      for capture <- edits ++ [deletion] do
        payload = Jason.decode!(capture["body"])
        event = payload["event"]
        action = if event["subtype"] == "message_changed", do: "changed", else: "deleted"

        assert {:ok,
                %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
                 LiveSmoke.replay(capture, webhook: Webhook, secret: secret),
               "#{spec.label} #{action} yields no signal"

        signal = Map.delete(signal, :delivery)

        assert {:ok, ^signal} = Webhook.normalize_event(payload)
        assert {:ok, ^signal} = Webhook.normalize_signal("#{spec.family}.#{action}", payload)

        assert signal.subtype == event["subtype"]
        assert signal.channel == env[spec.channel]
        assert signal.ts == posted.ts, "#{spec.label} #{action} ts"
        assert signal.notification_ts == event["ts"]
        refute signal.notification_ts == signal.ts
        assert Map.get(signal, :thread_ts) == Map.get(posted, :thread_ts)
        assert signal.user == posted.user
        signal
      end

    {edited, [deleted]} = Enum.split(signals, -1)

    for {signal, capture} <- Enum.zip(edited, edits) do
      message = Jason.decode!(capture["body"])["event"]["message"]
      assert signal.text == message["text"]
      assert signal.editor == message["edited"]["user"]
      assert signal.edited_ts == message["edited"]["ts"]
    end

    refute Map.has_key?(deleted, :text)

    event_ids = [posted.event_id | Enum.map(signals, & &1.event_id)]
    assert Enum.uniq(event_ids) == event_ids, "#{spec.label} event IDs repeat"

    refute_stored!(token, posted.channel, posted.ts, Map.get(posted, :thread_ts))

    IO.puts(
      "live_smoke slack: #{spec.label} #{posted.channel} #{posted.ts} " <>
        "edits #{edited |> Enum.map(& &1.event_id) |> Enum.join(",")} " <>
        "deletion #{deleted.event_id} keep the source ts; the post is gone"
    )
  end

  # The post and its edits and deletion, which name the post by its `ts` in
  # `message.ts` and `deleted_ts`.
  defp change_sequence!(captures, spec, env) do
    channel = env[spec.channel]

    original =
      Enum.find(captures, fn capture ->
        event = event(capture)

        event["type"] == "message" and event["subtype"] == nil and event["channel"] == channel and
          text_label(event["text"]) == spec.label
      end) || flunk("no first delivery of the post #{spec.label} in SLACK_CAPTURE_DIR")

    ts = event(original)["ts"]

    edits =
      Enum.filter(captures, fn capture ->
        event = event(capture)

        event["subtype"] == "message_changed" and event["channel"] == channel and
          get_in(event, ["message", "ts"]) == ts and is_map(get_in(event, ["message", "edited"]))
      end)

    assert length(edits) == spec.edits,
           "#{spec.label}: #{length(edits)} edits in SLACK_CAPTURE_DIR, expected #{spec.edits}"

    deletions =
      Enum.filter(captures, fn capture ->
        event = event(capture)

        event["subtype"] == "message_deleted" and event["channel"] == channel and
          event["deleted_ts"] == ts
      end)

    assert [deletion] = deletions, "#{spec.label}: #{length(deletions)} deletions"

    %{original: original, edits: edits, deletion: deletion}
  end

  defp assert_tombstone_sequence(sequence, secret, token, env) do
    %{ts: ts, parent: parent, tombstone: tombstone, removal: removal} = sequence
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]
    posted = event(parent)
    payload = Jason.decode!(tombstone["body"])

    assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
             LiveSmoke.replay(tombstone, webhook: Webhook, secret: secret),
           "the tombstone of #{ts} yields no signal"

    signal = Map.delete(signal, :delivery)

    assert {:ok, ^signal} = Webhook.normalize_event(payload)
    assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.deleted", payload)

    assert {:error, %ProviderError{reason: :not_an_edit}} =
             Webhook.normalize_signal("message.channels.changed", payload)

    assert %{subtype: "message_deleted", channel: ^channel, ts: ^ts, thread_ts: ^ts} = signal
    assert signal.notification_ts == payload["event"]["ts"]

    assert Map.take(signal, [:user, :bot_id, :app_id]) ==
             %{user: posted["user"], bot_id: posted["bot_id"], app_id: posted["app_id"]}

    for key <- [:text, :editor, :edited_ts], do: refute(Map.has_key?(signal, key))

    removed = if removal, do: assert_tombstone_removal(removal, signal, secret, token)

    IO.puts(
      "live_smoke slack: tombstone #{channel} #{ts} #{signal.event_id} is a deletion" <>
        if(removed, do: ", its removal #{removed.event_id} another; the parent is gone", else: "")
    )
  end

  defp assert_tombstone_removal(removal, deleted, secret, token) do
    %{channel: channel, ts: ts} = deleted

    assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: %{} = signal}} =
             LiveSmoke.replay(removal, webhook: Webhook, secret: secret),
           "the removal of the tombstone of #{ts} yields no signal"

    signal = Map.delete(signal, :delivery)
    payload = Jason.decode!(removal["body"])

    assert {:ok, ^signal} = Webhook.normalize_event(payload)
    assert {:ok, ^signal} = Webhook.normalize_signal("message.channels.deleted", payload)
    assert %{subtype: "message_deleted", channel: ^channel, ts: ^ts, thread_ts: ^ts} = signal
    refute signal.event_id == deleted.event_id

    for key <- [:user, :bot_id, :app_id, :text], do: refute(Map.has_key?(signal, key))

    refute_stored!(token, channel, ts, nil)
    signal
  end

  # Each tombstone in the public channel with the parent it replaces, found
  # by its `ts`, and the removal of the tombstone if Slack sent one.
  defp tombstone_sequences!(captures, env) do
    channel = env["SLACK_PUBLIC_CHANNEL_ID"]

    tombstones =
      Enum.filter(captures, fn capture ->
        event = event(capture)

        event["subtype"] == "message_changed" and event["channel"] == channel and
          tombstone?(event["message"])
      end)

    assert tombstones != [], "no tombstone in SLACK_CAPTURE_DIR"

    for tombstone <- tombstones do
      ts = event(tombstone)["message"]["ts"]

      parent =
        Enum.find(captures, fn capture ->
          event = event(capture)

          event["type"] == "message" and event["subtype"] == nil and
            event["channel"] == channel and event["ts"] == ts
        end) || flunk("no first delivery of the parent #{ts} in SLACK_CAPTURE_DIR")

      removal =
        Enum.find(captures, fn capture ->
          event = event(capture)

          event["subtype"] == "message_deleted" and event["channel"] == channel and
            event["deleted_ts"] == ts and tombstone?(event["previous_message"])
        end)

      %{ts: ts, parent: parent, tombstone: tombstone, removal: removal}
    end
  end

  defp tombstone?(%{"subtype" => "tombstone"}), do: true
  defp tombstone?(_message), do: false

  defp edited_parent?(%{tombstone: tombstone}),
    do: is_map(event(tombstone)["previous_message"]["edited"])

  defp unedited_change!(captures, spec, env) do
    Enum.find(captures, fn capture ->
      event = event(capture)

      event["subtype"] == "message_changed" and is_map(event["message"]) and
        not Map.has_key?(event["message"], "edited") and unedited?(spec.kind, event, env)
    end) || flunk("no first delivery of #{spec.kind} in SLACK_CAPTURE_DIR")
  end

  defp unedited?(:thread_parent, %{"message" => message} = event, env) do
    event["channel"] == env["SLACK_PUBLIC_CHANNEL_ID"] and message["thread_ts"] == message["ts"] and
      text_label(message["text"]) == "plain-public"
  end

  defp unedited?(:broadcast_root, %{"message" => message} = event, env) do
    event["channel"] == env["SLACK_PUBLIC_CHANNEL_ID"] and
      message["subtype"] == "thread_broadcast" and
      text_label(message["text"]) == "broadcast-reply"
  end

  defp unedited?(:unfurl, %{"message" => message}, _env) do
    Enum.any?(message["attachments"] || [], &(&1["is_msg_unfurl"] == true))
  end

  defp write_change!(capture, name, secret, extra_fields) do
    LiveSmoke.write_capture!(capture, :slack, name,
      secret: secret,
      fields: @capture_fields ++ extra_fields,
      name_keys: @capture_name_keys
    )
  end

  defp assert_kind(%{kind: :file_share}, signal, stored, _token, _env) do
    assert signal.file_ids == Enum.map(stored["files"], & &1["id"])
  end

  defp assert_kind(%{kind: kind} = spec, signal, stored, _token, env)
       when kind in [:direct_message, :group_direct_message] do
    type = if kind == :direct_message, do: "im", else: "mpim"

    assert signal.sender == %{id: stored["user"]}
    assert signal.conversation == %{id: env[spec.channel], type: type}
    refute Map.has_key?(signal, :shared_messages)
  end

  defp assert_kind(%{source_channel: source_channel}, signal, _stored, token, env) do
    assert [shared] = signal.shared_messages
    {_method, source} = stored_message!(token, shared.channel, shared.ts, nil)

    assert shared.channel == env[source_channel]
    assert shared.user == source["user"]
    assert shared.text == source["text"]
    assert shared.from_url =~ "/archives/#{shared.channel}/p#{String.replace(shared.ts, ".", "")}"

    IO.puts("live_smoke slack: shared #{shared.channel} #{shared.ts} matches its source")
  end

  defp assert_kind(_spec, signal, _stored, _token, _env) do
    refute Map.has_key?(signal, :file_ids)
    refute Map.has_key?(signal, :shared_messages)
  end

  # A reply's thread_ts. A parent is stored with its own ts as thread_ts.
  defp reply_thread_ts(%{"thread_ts" => ts, "ts" => ts}), do: nil
  defp reply_thread_ts(stored), do: stored["thread_ts"]

  defp deliveries!(env, specs) do
    captures = first_deliveries!(env)

    for spec <- specs do
      capture =
        Enum.find(captures, &matches?(spec, event(&1), env)) ||
          flunk("no first delivery of #{spec.kind} (label #{spec.label}) in SLACK_CAPTURE_DIR")

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

  defp matches?(spec, event, env) do
    event["type"] == spec.type and event["subtype"] == spec[:subtype] and
      event["channel"] == env[spec.channel] and
      label(spec, event) == spec.label
  end

  defp label(%{label_at: :shared_message}, %{"text" => ""} = event) do
    case Enum.filter(event["attachments"] || [], &(&1["is_share"] == true)) do
      [shared] -> text_label(shared["text"])
      _other -> nil
    end
  end

  defp label(%{label_at: :shared_message}, _event), do: nil
  defp label(_spec, %{"attachments" => [_ | _]}), do: nil
  defp label(_spec, event), do: text_label(event["text"])

  # The first word after any leading mentions.
  defp text_label(text) when is_binary(text) do
    text
    |> String.replace(~r/^(<@[A-Z0-9]+>\s*)+/, "")
    |> String.split(~r/\s/, parts: 2)
    |> hd()
  end

  defp text_label(_text), do: nil

  defp event(capture), do: capture["body"] |> Jason.decode!() |> Map.fetch!("event")

  # Reads the message `ts` of `channel` as Slack stores it: a reply through
  # conversations.replies of its thread, any other message through
  # conversations.history.
  defp stored_message!(token, channel, ts, thread_ts) do
    case read_stored(token, channel, ts, thread_ts) do
      {method, nil} -> flunk("conversations.#{method} has no message #{ts} in #{channel}")
      found -> found
    end
  end

  defp refute_stored!(token, channel, ts, thread_ts) do
    assert {_method, nil} = read_stored(token, channel, ts, thread_ts),
           "the deleted message #{ts} is still in #{channel}"
  end

  defp read_stored(token, channel, ts, thread_ts) do
    {method, params} =
      if thread_ts in [nil, ts],
        do: {"history", []},
        else: {"replies", [ts: thread_ts]}

    params =
      [channel: channel, oldest: ts, latest: ts, inclusive: true, limit: 1] ++ params

    case LiveSlack.reference_request(token, :get, "conversations.#{method}", params: params) do
      %{status: 200, body: %{"ok" => true, "messages" => messages}} ->
        {method, Enum.find(messages, &(&1["ts"] == ts))}

      %{status: status, body: body} ->
        flunk("conversations.#{method} for #{channel}: HTTP #{status}, #{slack_error(body)}")
    end
  end

  defp slack_error(%{"error" => error}) when is_binary(error), do: error
  defp slack_error(_body), do: "no Slack error code"
end
