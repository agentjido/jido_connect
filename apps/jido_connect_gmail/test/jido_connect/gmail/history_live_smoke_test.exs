defmodule Jido.Connect.Gmail.HistoryLiveSmokeTest do
  @moduledoc """
  Live checks of the new-message and change polls and of Trash against the
  Google Workspace test account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  The change poll must turn a history ID older than Gmail's history into a
  checkpoint reset and report archive, Trash, restore and permanent delete of
  the disposable message as one change each. Trash and restore must answer
  with an inserted message and with its one-message thread. The received poll
  must report an inserted message and its reply with one thread ID.

  The tests read `GOOGLE_ACCESS_TOKEN`, `GOOGLE_GMAIL_METADATA_ACCESS_TOKEN`
  and `GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID`. All but the checkpoint reset write
  to the mailbox and run only with `GOOGLE_LIVE_DESTRUCTIVE=true`. The change
  poll deletes the disposable message for good, so the next run needs the
  test data seeded again; the messages that a test inserts are deleted when it
  exits. See `docs/live_smoke_tests.md` for the variables and the recording
  mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Client
  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  # google.gmail.message.changed. The polls run on a metadata-only lease with
  # the gmail.metadata token. The write steps run through the write actions on
  # the full grant, prepared and committed with a host authorization as a
  # host would run them, and before any recording starts, so the recordings
  # hold only the poll under test.

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"

  # Gmail's history can trail a write. A wait for it polls at most this often,
  # 2 s apart, and so sleeps at most 28 s; a test that waits sets its timeout
  # for all of its waits.
  @history_polls 15

  @tag env!(["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"])
  test "the change poll turns a history ID older than Gmail's history into a checkpoint reset",
       %{env: env} do
    LiveGmail.record("message_changed_expired")

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 404,
              details: %{
                checkpoint: "1",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} = poll_changes(%{}, "1", env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"])
  end

  @tag env!([
         "GOOGLE_ACCESS_TOKEN",
         "GOOGLE_GMAIL_METADATA_ACCESS_TOKEN",
         "GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID"
       ])
  @tag write!(:google)
  @tag timeout: :timer.minutes(5)
  test "the change poll reports archive, Trash, restore and permanent delete of the disposable message",
       %{env: env} do
    metadata_token = env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(env["GOOGLE_ACCESS_TOKEN"])
    message_id = env["GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID"]

    assert {:ok, %{message: %{thread_id: thread_id, label_ids: labels}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.get",
               %{message_id: message_id},
               context: grant.context,
               credential_lease: grant.lease
             )

    assert "INBOX" in labels
    refute "TRASH" in labels
    archived = Enum.sort(labels -- ["INBOX"])

    # Each step is one change of the message: archive removes INBOX, Trash
    # adds TRASH, restore removes TRASH and leaves the labels from before
    # Trash, and permanent delete reports no changed and no remaining labels.
    steps = [
      {"google.gmail.message.labels.apply",
       %{message_id: message_id, remove_label_ids: ["INBOX"]},
       {"label_removed", ["INBOX"], archived}},
      {"google.gmail.message.trash", %{message_id: message_id},
       {"label_added", ["TRASH"], Enum.sort(["TRASH" | archived])}},
      {"google.gmail.message.untrash", %{message_id: message_id},
       {"label_removed", ["TRASH"], archived}},
      {"google.gmail.message.delete", %{message_id: message_id}, {"message_deleted", [], []}}
    ]

    assert {:ok, %{signals: [], checkpoint: start}} = poll_changes(%{}, nil, metadata_token)

    final =
      Enum.reduce(steps, start, fn {action_id, input, expected}, checkpoint ->
        assert {:ok, _output} = LiveGmail.commit(grant, action_id, input)

        {signals, next} =
          await_history(
            &poll_changes(%{}, &1, metadata_token),
            checkpoint,
            &(changes(&1, message_id) != [])
          )

        assert changes(signals, message_id) == [expected]
        assert Enum.all?(signals, &(&1.message_id != message_id or &1.thread_id == thread_id))
        assert String.to_integer(next) > String.to_integer(checkpoint)
        next
      end)

    # The whole run from the first checkpoint, two history records per page.
    LiveGmail.record("message_changed_history")

    assert {:ok, %{signals: signals, checkpoint: checkpoint}} =
             poll_changes(%{page_size: 2}, start, metadata_token)

    assert changes(signals, message_id) == Enum.map(steps, &elem(&1, 2))
    assert String.to_integer(checkpoint) >= String.to_integer(final)
  end

  # The trash and untrash calls for a message and for a thread, committed
  # through the write actions. The test inserts its own one-message thread
  # into the inbox and deletes it for good when it exits, because the change
  # poll above deletes the disposable message. The message is read before the
  # first recording starts, so each recording holds only the answer to its
  # write. Trash takes the message out of the inbox and restore does not put
  # it back, so the thread steps run on an archived message.
  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  @tag write!(:google)
  test "trash and untrash answer with an inserted message and its one-message thread",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)

    %{"id" => message_id} =
      LiveGmail.insert_message!(
        access_token,
        [{"Subject", "jcl-live trash #{LiveGmail.run_id()}"}],
        ["INBOX"]
      )

    assert {:ok, %{message: %{thread_id: thread_id, label_ids: labels}}} =
             LiveGmail.invoke(grant, "google.gmail.message.get", %{message_id: message_id})

    assert "INBOX" in labels
    refute "TRASH" in labels

    assert {:ok, %{thread: %{thread_id: ^thread_id, messages: [%{message_id: ^message_id}]}}} =
             LiveGmail.invoke(grant, "google.gmail.thread.get", %{thread_id: thread_id})

    LiveGmail.record("message_trash")

    assert {:ok, %{message: %{message_id: ^message_id, label_ids: trashed}}} =
             LiveGmail.commit(grant, "google.gmail.message.trash", %{message_id: message_id})

    assert "TRASH" in trashed
    refute "INBOX" in trashed

    LiveGmail.record("message_untrash")

    assert {:ok, %{message: %{message_id: ^message_id, label_ids: restored}}} =
             LiveGmail.commit(grant, "google.gmail.message.untrash", %{message_id: message_id})

    refute "TRASH" in restored
    refute "INBOX" in restored

    LiveGmail.record("thread_trash")

    assert {:ok,
            %{
              thread: %{
                thread_id: ^thread_id,
                messages: [%{message_id: ^message_id, label_ids: thread_trashed}]
              }
            }} = LiveGmail.commit(grant, "google.gmail.thread.trash", %{thread_id: thread_id})

    assert "TRASH" in thread_trashed

    LiveGmail.record("thread_untrash")

    assert {:ok,
            %{
              thread: %{
                thread_id: ^thread_id,
                messages: [%{message_id: ^message_id, label_ids: thread_restored}]
              }
            }} = LiveGmail.commit(grant, "google.gmail.thread.untrash", %{thread_id: thread_id})

    refute "TRASH" in thread_restored
  end

  # google.gmail.message.received. The poll runs on a metadata-only lease from
  # a checkpoint it initializes from the profile. Such a checkpoint replays no
  # earlier history, so the test inserts a new message and a reply to it into
  # the inbox after the first poll. messages.insert files them like received
  # mail and sends nothing; both are deleted for good when the test exits.

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"])
  @tag write!(:google)
  @tag timeout: :timer.minutes(2)
  test "the received poll reports an inserted message and its reply with one thread ID",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    metadata_token = env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"]

    assert {:ok, %{signals: [], checkpoint: start}} = poll_received(nil, metadata_token)

    run = LiveGmail.run_id()
    subject = "jcl-live received #{run}"
    original_header_id = "<jcl-live-received-#{run}-1@example.org>"

    %{"id" => original_id, "threadId" => thread_id} =
      LiveGmail.insert_message!(
        access_token,
        [{"Subject", subject}, {"Message-ID", original_header_id}],
        ["INBOX", "UNREAD"]
      )

    reply =
      LiveGmail.insert_message!(
        access_token,
        [
          {"Subject", "Re: " <> subject},
          {"Message-ID", "<jcl-live-received-#{run}-2@example.org>"},
          {"In-Reply-To", original_header_id},
          {"References", original_header_id}
        ],
        ["INBOX", "UNREAD"],
        thread_id
      )

    assert %{"id" => reply_id, "threadId" => ^thread_id} = reply
    assert reply_id != original_id
    message_ids = [original_id, reply_id]

    {signals, next} =
      await_history(&poll_received(&1, metadata_token), start, fn signals ->
        message_ids -- Enum.map(signals, & &1.message_id) == []
      end)

    # One signal per message, the reply after its original, both in one thread.
    assert [
             %{message_id: ^original_id, thread_id: ^thread_id} = original_signal,
             %{message_id: ^reply_id, thread_id: ^thread_id} = reply_signal
           ] = received(signals, message_ids)

    assert "INBOX" in original_signal.label_ids
    assert "INBOX" in reply_signal.label_ids
    assert String.to_integer(next) > String.to_integer(start)

    # The run from the initialized checkpoint once more, as one recording.
    LiveGmail.record("message_received_history")

    assert {:ok, %{signals: recorded, checkpoint: checkpoint}} =
             poll_received(start, metadata_token)

    assert received(recorded, message_ids) == received(signals, message_ids)

    assert String.to_integer(checkpoint) >= String.to_integer(next)

    # Recordings for the offline poll tests: the first one-record page of the
    # same history, and Google's answer to a page token it never issued.
    page = %{
      start_history_id: start,
      label_id: "INBOX",
      page_size: 1,
      history_types: ["messageAdded"]
    }

    LiveGmail.record("message_received_history_first_page")
    assert {:ok, %{next_page_token: page_token}} = Client.list_history(page, metadata_token)
    assert is_binary(page_token)

    LiveGmail.record("message_received_history_invalid_page_token")

    assert {:error, %Connect.Error.ProviderError{}} =
             Client.list_history(Map.put(page, :page_token, "jcl-live-invalid"), metadata_token)
  end

  defp received(signals, message_ids), do: Enum.filter(signals, &(&1.message_id in message_ids))

  defp poll_received(checkpoint, metadata_token) do
    {context, lease} = LiveGmail.grant(metadata_token, [@metadata_scope])

    Connect.poll(Gmail.integration(), "google.gmail.message.received", %{},
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  # Runs `poll` from `checkpoint` until `done?` accepts the signals of one
  # poll and returns those signals with the next checkpoint.
  defp await_history(poll, checkpoint, done?, attempt \\ 1) do
    assert {:ok, %{signals: signals, checkpoint: next}} = poll.(checkpoint)

    cond do
      done?.(signals) ->
        {signals, next}

      attempt < @history_polls ->
        Process.sleep(2_000)
        await_history(poll, checkpoint, done?, attempt + 1)

      true ->
        flunk("Gmail history lacked the expected signals after #{attempt} polls")
    end
  end

  defp changes(signals, message_id) do
    for %{message_id: ^message_id} = signal <- signals do
      {signal.change_type, signal.changed_label_ids, Enum.sort(signal.label_ids)}
    end
  end

  defp poll_changes(config, checkpoint, metadata_token) do
    {context, lease} = LiveGmail.grant(metadata_token, [@metadata_scope])

    Connect.poll(Gmail.integration(), "google.gmail.message.changed", config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end
end
