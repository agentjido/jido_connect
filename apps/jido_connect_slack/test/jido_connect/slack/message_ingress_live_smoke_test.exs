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

  The second test replays the first edit and the deletion of `edit-public`:
  both verify, and neither yields a message signal.

  With `JIDO_CONNECT_RECORD=1` each delivery the tests use becomes the
  fixture `test/fixtures/slack/captured/<name>.json`, sanitized and signed
  again with `LiveSmoke.replay_secret/0`. Message texts stay, because the
  offline tests check text beyond 512 bytes; they are checklist test data.
  File previews and file links, and the share fields that carry the
  workspace URL, the author's handle or avatar, become placeholders.
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

  @revision_kinds [
    %{
      kind: :message_changed,
      fixture: "message_changed",
      type: "message",
      subtype: "message_changed",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label_at: "message",
      label: "edit-public"
    },
    %{
      kind: :message_deleted,
      fixture: "message_deleted",
      type: "message",
      subtype: "message_deleted",
      channel: "SLACK_PUBLIC_CHANNEL_ID",
      label_at: "previous_message",
      label: "edit-public"
    }
  ]

  @tag env!(@env)
  test "captured message deliveries normalize to the messages Slack stores", %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]
    token = env["SLACK_BOT_TOKEN"]
    deliveries = deliveries!(env, @message_kinds ++ @revision_kinds)

    if LiveSmoke.recording?() do
      for {spec, capture} <- deliveries do
        LiveSmoke.write_capture!(capture, :slack, spec.fixture,
          secret: secret,
          fields: @capture_fields,
          name_keys: @capture_name_keys
        )
      end
    end

    for {spec, capture} <- Enum.filter(deliveries, &message_kind?/1) do
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
  test "captured edits and deletions verify without a message signal", %{env: env} do
    secret = env["SLACK_SIGNING_SECRET"]

    for {spec, capture} <- deliveries!(env, @revision_kinds) do
      event = event(capture)

      assert {:ok, %WebhookDelivery{signature_state: :verified, normalized_signal: nil}} =
               LiveSmoke.replay(capture, webhook: Webhook, secret: secret),
             "#{spec.kind} yields a signal"

      assert {:error, %ProviderError{reason: :unsupported_message_subtype}} =
               capture["body"] |> Jason.decode!() |> Webhook.normalize_event()

      IO.puts(
        "live_smoke slack: #{spec.kind} #{event["channel"]} #{event["ts"]} has no message signal"
      )
    end
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

  defp message_kind?({spec, _capture}), do: spec in @message_kinds

  defp deliveries!(env, specs) do
    captures =
      env["SLACK_CAPTURE_DIR"]
      |> Path.join("slack-events-*.json")
      |> Path.wildcard()
      |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
      |> Enum.reject(&Map.has_key?(&1["headers"], "x-slack-retry-num"))
      |> Enum.sort_by(& &1["captured_at"])

    for spec <- specs do
      capture =
        Enum.find(captures, &matches?(spec, event(&1), env)) ||
          flunk("no first delivery of #{spec.kind} (label #{spec.label}) in SLACK_CAPTURE_DIR")

      {spec, capture}
    end
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
  defp label(%{label_at: key}, event), do: text_label(get_in(event, [key, "text"]))
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
    {method, params} =
      if thread_ts in [nil, ts],
        do: {"history", []},
        else: {"replies", [ts: thread_ts]}

    params =
      [channel: channel, oldest: ts, latest: ts, inclusive: true, limit: 1] ++ params

    case LiveSlack.reference_request(token, :get, "conversations.#{method}", params: params) do
      %{status: 200, body: %{"ok" => true, "messages" => messages}} ->
        stored =
          Enum.find(messages, &(&1["ts"] == ts)) ||
            flunk("conversations.#{method} has no message #{ts} in #{channel}")

        {method, stored}

      %{status: status, body: body} ->
        flunk("conversations.#{method} for #{channel}: HTTP #{status}, #{slack_error(body)}")
    end
  end

  defp slack_error(%{"error" => error}) when is_binary(error), do: error
  defp slack_error(_body), do: "no Slack error code"
end
