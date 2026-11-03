defmodule Jido.Connect.Gmail.SendLiveSmokeTest do
  @moduledoc """
  Live checks of sending mail and of drafts with the Google Workspace test
  account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke test/jido_connect/gmail/send_live_smoke_test.exs

  `google.gmail.message.send` must send a new mail to `GOOGLE_GMAIL_RECIPIENT`
  and a reply to it with `thread_id`, `in_reply_to` and `references` taken
  from the first mail. Gmail must store both bodies as sent, the reply in the
  thread of the first mail and its `In-Reply-To` and `References` as the
  first mail's `Message-ID`.

  `google.gmail.draft.create` and `google.gmail.draft.update` must create a
  reply draft in the thread of an inserted message and replace it under the
  same draft ID with a new message. Gmail must store both versions with their
  own body and the reply headers as a draft that was not sent.

  The tests read `GOOGLE_ACCESS_TOKEN` and `GOOGLE_GMAIL_RECIPIENT` and run
  only with `GOOGLE_LIVE_DESTRUCTIVE=true`. Each run of the send test puts two
  mails into the recipient's mailbox, which stay there. When they exit, also
  after a failure, the tests delete the sender's copies of both mails, the
  draft and the inserted message. See `docs/live_smoke_tests.md` for the
  variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  # The writes run through the actions on the full grant, prepared and
  # committed with a host authorization as a host would run them. Each
  # recording holds the answer to one write. The checks read what Gmail
  # stores directly, in format=raw, outside the connector and the recorder.

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_RECIPIENT"])
  @tag write!(:google)
  test "message.send sends a new mail and a reply in its thread to the recipient",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)
    run = LiveGmail.run_id()
    subject = "jcl-live send #{run}"

    original = %{
      to: [env["GOOGLE_GMAIL_RECIPIENT"]],
      subject: subject,
      body_text: "Synthetic mail of a jcl-live send check, run #{run}. Grüße."
    }

    LiveGmail.record("message_send")
    sent = LiveGmail.commit(grant, "google.gmail.message.send", original)
    delete_sent_on_exit(access_token, sent)

    assert {:ok, %{message: %{message_id: original_id, thread_id: thread_id, label_ids: labels}}} =
             sent

    assert "SENT" in labels

    stored_original = stored_message!(access_token, original_id)
    assert stored_original.body_sha256 == LiveGmail.sha256(original.body_text)
    assert %{"subject" => [^subject], "message-id" => [header_id]} = stored_original.headers

    reply_subject = "Re: " <> subject

    reply = %{
      to: original.to,
      subject: reply_subject,
      body_text: "Synthetic reply of a jcl-live send check, run #{run}. Grüße.",
      thread_id: thread_id,
      in_reply_to: header_id,
      references: header_id
    }

    LiveGmail.record("message_send_reply")
    replied = LiveGmail.commit(grant, "google.gmail.message.send", reply)
    delete_sent_on_exit(access_token, replied)

    assert {:ok, %{message: %{message_id: reply_id, thread_id: ^thread_id, label_ids: labels}}} =
             replied

    assert "SENT" in labels
    assert reply_id != original_id

    stored_reply = stored_message!(access_token, reply_id)
    assert stored_reply.body_sha256 == LiveGmail.sha256(reply.body_text)

    assert %{
             "subject" => [^reply_subject],
             "in-reply-to" => [^header_id],
             "references" => [^header_id]
           } = stored_reply.headers

    assert thread_message_ids!(access_token, thread_id) == [original_id, reply_id]
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_RECIPIENT"])
  @tag write!(:google)
  test "draft.create and draft.update replace one reply draft in a thread without sending it",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = LiveGmail.write_grant(access_token)
    run = LiveGmail.run_id()
    subject = "jcl-live draft #{run}"
    original_header_id = "<jcl-live-draft-#{run}@example.org>"

    %{"id" => original_id, "threadId" => thread_id} =
      LiveGmail.insert_message!(
        access_token,
        [{"Subject", subject}, {"Message-ID", original_header_id}],
        ["INBOX"]
      )

    reply_subject = "Re: " <> subject

    reply = %{
      to: [env["GOOGLE_GMAIL_RECIPIENT"]],
      subject: reply_subject,
      body_text: "First version of a jcl-live draft check, run #{run}. Grüße.",
      thread_id: thread_id,
      in_reply_to: original_header_id,
      references: original_header_id
    }

    LiveGmail.record("draft_create")
    created = LiveGmail.commit(grant, "google.gmail.draft.create", reply)
    delete_draft_on_exit(access_token, created)

    assert {:ok,
            %{
              draft: %{
                draft_id: draft_id,
                message: %{message_id: first_message_id, thread_id: ^thread_id}
              }
            }} = created

    assert_unsent_reply_draft(access_token, draft_id, first_message_id, reply, original_header_id)

    replacement =
      reply
      |> Map.put(:draft_id, draft_id)
      |> Map.put(:body_text, "Replacement of a jcl-live draft check, run #{run}. Grüße.")

    LiveGmail.record("draft_update")

    assert {:ok,
            %{
              draft: %{
                draft_id: ^draft_id,
                message: %{message_id: message_id, thread_id: ^thread_id}
              }
            }} = LiveGmail.commit(grant, "google.gmail.draft.update", replacement)

    assert message_id != first_message_id

    assert_unsent_reply_draft(
      access_token,
      draft_id,
      message_id,
      replacement,
      original_header_id
    )

    assert thread_message_ids!(access_token, thread_id) == [original_id, message_id]
  end

  # The draft as Gmail stores it holds `message_id`, carries DRAFT and not
  # SENT, and has the body, the subject and the threading headers of `input`,
  # a reply to `header_id`.
  defp assert_unsent_reply_draft(access_token, draft_id, message_id, input, header_id) do
    stored = stored_draft!(access_token, draft_id)
    subject = input.subject

    assert stored.message_id == message_id
    assert "DRAFT" in stored.label_ids
    refute "SENT" in stored.label_ids
    assert stored.body_sha256 == LiveGmail.sha256(input.body_text)

    assert %{
             "subject" => [^subject],
             "in-reply-to" => [^header_id],
             "references" => [^header_id]
           } = stored.headers
  end

  # Each cleanup is registered as soon as a write has answered with an ID,
  # before any assertion, so a failed check still removes what was created.
  defp delete_sent_on_exit(access_token, {:ok, %{message: %{message_id: message_id}}}),
    do: on_exit(fn -> LiveGmail.delete_message!(access_token, message_id) end)

  defp delete_sent_on_exit(_access_token, _result), do: :ok

  defp delete_draft_on_exit(access_token, {:ok, %{draft: %{draft_id: draft_id}}}),
    do: on_exit(fn -> LiveGmail.delete_draft!(access_token, draft_id) end)

  defp delete_draft_on_exit(_access_token, _result), do: :ok

  # A message or draft as Gmail stores it: its message ID and labels, the
  # subject, Message-ID and threading headers, and the SHA-256 of the body
  # after the header block. Only these headers are kept, so a failed
  # assertion shows no address.
  defp stored_message!(access_token, message_id) do
    case LiveGmail.gmail_api(:get, "/messages/#{message_id}", access_token,
           params: [format: "raw"]
         ) do
      %{status: 200, body: message} -> stored(message)
      %{status: status} -> flunk("could not read stored message #{message_id}: HTTP #{status}")
    end
  end

  defp stored_draft!(access_token, draft_id) do
    case LiveGmail.gmail_api(:get, "/drafts/#{draft_id}", access_token, params: [format: "raw"]) do
      %{status: 200, body: %{"message" => message}} -> stored(message)
      %{status: status} -> flunk("could not read the stored draft: HTTP #{status}")
    end
  end

  defp stored(%{"id" => id, "raw" => raw} = message) do
    {head, body} =
      case raw |> Base.url_decode64!(padding: false) |> :binary.split("\r\n\r\n") do
        [head, body] -> {head, body}
        _other -> flunk("the stored message #{id} has no CRLF line between headers and body")
      end

    headers =
      head
      |> String.replace(~r/\r\n[ \t]+/, " ")
      |> String.split("\r\n")
      |> Enum.map(&String.split(&1, ":", parts: 2))
      |> Enum.group_by(&String.downcase(hd(&1)), &String.trim(List.last(&1)))
      |> Map.take(["subject", "message-id", "in-reply-to", "references"])

    %{
      message_id: id,
      label_ids: Map.get(message, "labelIds", []),
      headers: headers,
      body_sha256: LiveGmail.sha256(body)
    }
  end

  defp thread_message_ids!(access_token, thread_id) do
    case LiveGmail.gmail_api(:get, "/threads/#{thread_id}", access_token,
           params: [format: "minimal"]
         ) do
      %{status: 200, body: %{"messages" => messages}} -> Enum.map(messages, & &1["id"])
      %{status: status} -> flunk("could not read thread #{thread_id}: HTTP #{status}")
    end
  end
end
