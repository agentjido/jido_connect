defmodule Jido.Connect.Gmail.LabelsLiveSmokeTest do
  @moduledoc """
  Live checks of processing labels and of archiving one message, on the
  archive pair of the Google Workspace test account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  `google.gmail.message.labels.apply` must add and remove the test label and
  `UNREAD`, archive one message while it keeps its other labels and read state
  and its sibling keeps every label, and mark it read. It must fail with 404
  for a message deleted for good. Each test restores the labels it changes
  when it exits.

  The tests read `GOOGLE_ACCESS_TOKEN`, `GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID` and
  `GOOGLE_GMAIL_LABEL_ID` and run only with `GOOGLE_LIVE_DESTRUCTIVE=true`;
  see `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  # google.gmail.message.labels.apply on the archive pair: two messages of one
  # thread, both in the inbox. Each test checks the pair before its first
  # write and, when it exits, restores the labels it changes, also after a
  # failed assertion, so the tests leave the pair as they found it.

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID", "GOOGLE_GMAIL_LABEL_ID"])
  @tag write!(:google)
  test "labels.apply adds and removes the test label and UNREAD on one message of the archive pair",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)
    message_id = env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]
    label_id = env["GOOGLE_GMAIL_LABEL_ID"]

    {thread_id, pair} = archive_pair!(grant, message_id)
    refute Enum.any?(Map.values(pair), &(label_id in &1))
    labels = pair[message_id]
    restore_labels_on_exit(access_token, message_id, labels, [label_id, "UNREAD"])

    # The first step adds the test label and flips the read state, the second
    # removes the label and flips the read state back, so UNREAD is added once
    # and removed once whatever the message's read state was.
    {first, second} =
      if "UNREAD" in labels do
        {%{add_label_ids: [label_id], remove_label_ids: ["UNREAD"]},
         %{add_label_ids: ["UNREAD"], remove_label_ids: [label_id]}}
      else
        {%{add_label_ids: [label_id, "UNREAD"], remove_label_ids: []},
         %{add_label_ids: [], remove_label_ids: [label_id, "UNREAD"]}}
      end

    # After each step the thread holds the expected labels on the message and
    # the labels from before the test on its sibling.
    final =
      Enum.reduce([first, second], pair, fn step, before ->
        expected =
          Enum.sort((before[message_id] -- step.remove_label_ids) ++ step.add_label_ids)

        assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = changed}} =
                 LiveGmail.commit(
                   grant,
                   "google.gmail.message.labels.apply",
                   Map.put(step, :message_id, message_id)
                 )

        assert Enum.sort(changed.label_ids) == expected
        assert thread_labels(grant, thread_id) == %{before | message_id => expected}
        %{before | message_id => expected}
      end)

    assert final == pair
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"])
  @tag write!(:google)
  test "labels.apply archives one message of the archive pair and keeps its other labels and its sibling",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)
    message_id = env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]

    {thread_id, pair} = archive_pair!(grant, message_id)
    labels = pair[message_id]
    restore_labels_on_exit(access_token, message_id, labels, ["INBOX"])
    archived = labels -- ["INBOX"]

    # The answer to the archive request alone; prepare does not call Gmail.
    LiveGmail.record("message_modify_archive")

    assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = changed}} =
             LiveGmail.commit(grant, "google.gmail.message.labels.apply", %{
               message_id: message_id,
               add_label_ids: [],
               remove_label_ids: ["INBOX"]
             })

    assert Enum.sort(changed.label_ids) == archived

    # The archived message stays retrievable with its other labels and its
    # read state; its sibling keeps every label, INBOX included.
    LiveGmail.record("message_metadata_archived")

    assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = read_back}} =
             LiveGmail.invoke(grant, "google.gmail.message.get", %{message_id: message_id})

    assert Enum.sort(read_back.label_ids) == archived
    assert "UNREAD" in read_back.label_ids == "UNREAD" in labels

    LiveGmail.record("thread_metadata_archive_pair")
    assert thread_labels(grant, thread_id) == %{pair | message_id => archived}
  end

  # Recordings for the offline label tests: the answer to removing only
  # UNREAD from one message of the archive pair, and Google's answer to a
  # label change of a message deleted for good. A read message is marked
  # unread first, outside the recorder.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"])
  @tag write!(:google)
  test "labels.apply marks one message of the archive pair read and rejects a deleted message",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)
    message_id = env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]

    {_thread_id, pair} = archive_pair!(grant, message_id)
    labels = pair[message_id]
    restore_labels_on_exit(access_token, message_id, labels, ["UNREAD"])

    unless "UNREAD" in labels do
      body = %{"addLabelIds" => ["UNREAD"], "removeLabelIds" => []}

      assert %{status: 200} =
               LiveGmail.gmail_api(:post, "/messages/#{message_id}/modify", access_token,
                 json: body
               )
    end

    LiveGmail.record("message_modify_read")

    assert {:ok, %{message: %{message_id: ^message_id, label_ids: read}}} =
             LiveGmail.commit(grant, "google.gmail.message.labels.apply", %{
               message_id: message_id,
               add_label_ids: [],
               remove_label_ids: ["UNREAD"]
             })

    assert Enum.sort(read) == labels -- ["UNREAD"]

    %{"id" => deleted_id} =
      LiveGmail.insert_message!(
        access_token,
        [{"Subject", "jcl-live deleted #{LiveGmail.run_id()}"}],
        ["INBOX"]
      )

    LiveGmail.delete_message!(access_token, deleted_id)

    LiveGmail.record("message_modify_unknown_id")

    assert {:error, %Connect.Error.ProviderError{status: 404}} =
             LiveGmail.commit(grant, "google.gmail.message.labels.apply", %{
               message_id: deleted_id,
               add_label_ids: [],
               remove_label_ids: ["INBOX"]
             })
  end

  # Reads the archive pair through the read actions and checks it before a
  # write: the thread of `message_id` holds two messages, both in the inbox
  # and neither in Trash. Returns the thread ID and the sorted labels by
  # message ID.
  defp archive_pair!(grant, message_id) do
    assert {:ok, %{message: %{message_id: ^message_id, thread_id: thread_id}}} =
             LiveGmail.invoke(grant, "google.gmail.message.get", %{message_id: message_id})

    pair = thread_labels(grant, thread_id)
    assert [_sibling_id] = Map.keys(pair) -- [message_id]

    for {_id, labels} <- pair do
      assert "INBOX" in labels
      refute "TRASH" in labels
    end

    {thread_id, pair}
  end

  defp thread_labels(grant, thread_id) do
    assert {:ok, %{thread: %{thread_id: ^thread_id, messages: messages}}} =
             LiveGmail.invoke(grant, "google.gmail.thread.get", %{thread_id: thread_id})

    Map.new(messages, &{&1.message_id, Enum.sort(&1.label_ids)})
  end

  # When the test exits, puts back the labels of `touched` that `message_id`
  # had in `label_ids` and removes those it did not have.
  defp restore_labels_on_exit(access_token, message_id, label_ids, touched) do
    on_exit(fn ->
      current =
        case LiveGmail.gmail_api(:get, "/messages/#{message_id}?format=minimal", access_token) do
          %{status: 200, body: body} -> Map.get(body, "labelIds", [])
          %{status: status} -> raise "cleanup could not read #{message_id}: HTTP #{status}"
        end

      add = for id <- touched, id in label_ids, id not in current, do: id
      remove = for id <- touched, id in current, id not in label_ids, do: id

      if add != [] or remove != [] do
        body = %{"addLabelIds" => add, "removeLabelIds" => remove}

        case LiveGmail.gmail_api(:post, "/messages/#{message_id}/modify", access_token,
               json: body
             ) do
          %{status: 200} -> :ok
          %{status: status} -> raise "cleanup could not relabel #{message_id}: HTTP #{status}"
        end
      end
    end)
  end
end
