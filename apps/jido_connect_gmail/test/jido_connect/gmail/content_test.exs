defmodule Jido.Connect.Gmail.ContentTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.TestSupport.LiveSmoke

  # Runs the content actions through Jido.Connect.invoke/4 and the Gmail
  # client against Req.Test. Every response body is recorded from the prepared
  # messages of the live test account; content_live_smoke_test.exs records them.
  # A test that needs a shape the recordings lack derives it from a recording
  # and says so. Each test expects exactly the requests it lists, so any further
  # request, such as an attachment fetch, fails it.
  #
  # Gmail keeps a large body text part behind an attachmentId, and
  # attachments.get returns its original bytes. The prepared large-body message
  # shows both live: its 3 MB windows-1252 text/plain part comes back that way
  # in format=full, and attachments.get returns the windows-1252 bytes. That
  # attachments.get response is about 4 MB and is not recorded. The tests that
  # fetch a body text part therefore serve a small recorded attachments.get
  # response instead, and each says which.

  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gmail, :gmail_api_base_url, "https://gmail.test")

    Application.put_env(:jido_connect_google, :google_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_gmail, :gmail_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  describe "google.gmail.message.content.get" do
    test "an attached forward yields each original's headers and parts under its part ID" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_attached")
      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", recorded)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert [%{part_id: "0", content: "Two originals attached as messages.\r\n"}] =
               message.text_parts

      assert message.attachments == []
      assert [original, simple] = message.messages

      assert %{
               part_id: "1",
               filename: "original.eml",
               mime_type: "message/rfc822",
               disposition: "attachment"
             } = original

      assert header(original, "From") == "Person 3 <person-4@example.com>"
      assert header(original, "Date") == "Mon, 26 Oct 2026 15:30:21 +0000"
      assert header(original, "Subject") == "jcl-live attached original"

      assert Enum.map(original.text_parts, &{&1.part_id, &1.mime_type, &1.content}) == [
               {"1.0.0.0", "text/plain",
                "Attached original with marker jcl-marker-forward-attached.\r\n"},
               {"1.0.0.1", "text/html",
                "<p>Attached original with marker <b>jcl-marker-forward-attached</b>.</p>"}
             ]

      assert [%{part_id: "1.0.1", filename: "inner.txt", attachment_id: inner_id}] =
               original.attachments

      assert is_binary(inner_id)
      assert original.messages == []

      assert %{part_id: "2", filename: "simple.eml"} = simple
      assert header(simple, "Subject") == "jcl-live simple original"

      assert [
               %{
                 part_id: "2.0",
                 content: "A single-part original, marker jcl-marker-forward-simple.\r\n"
               }
             ] =
               simple.text_parts

      for nested <- [original, simple] do
        refute Map.has_key?(nested, :external_text_parts)
      end
    end

    test "an inline forward keeps the quoted original in the outer text with all headers and the manifest" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_inline")
      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", recorded)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert [%{part_id: "0.0", mime_type: "text/plain"} = plain, %{part_id: "0.1"} = html] =
               message.text_parts

      assert plain.content ==
               """
               Zur Info, siehe unten.\r
               \r
               ---------- Forwarded message ---------\r
               From: Original Sender <original.sender@example.org>\r
               Date: Fri, 30 Oct 2026 09:22:46 +0000\r
               Subject: jcl-live original\r
               To: <original.recipient@example.org>\r
               \r
               Original body, line one.\r
               Original body with marker jcl-marker-forward-inline.\r
               """

      assert html.content =~ "---------- Forwarded message ---------<br>"
      assert html.content =~ "Original body with marker jcl-marker-forward-inline."
      refute plain.content == recorded["snippet"]

      assert message.headers ==
               Enum.map(recorded["payload"]["headers"], &%{name: &1["name"], value: &1["value"]})

      assert %{subject: "Fwd: jcl-live original", from: "Person 1 <person-1@example.com>"} =
               message

      assert [
               %{
                 part_id: "1",
                 filename: "original-attachment.txt",
                 mime_type: "text/plain",
                 size: 37,
                 disposition: "attachment",
                 attachment_id: attachment_id
               }
             ] = message.attachments

      assert is_binary(attachment_id)
      assert message.messages == []

      # The result names what Gmail returned and nothing more: no field claims
      # a verified sender or a split of comment and quoted original.
      assert message |> Map.keys() |> Enum.sort() ==
               Enum.sort([
                 :message_id,
                 :thread_id,
                 :history_id,
                 :label_ids,
                 :internal_date,
                 :headers,
                 :from,
                 :to,
                 :cc,
                 :bcc,
                 :reply_to,
                 :subject,
                 :date,
                 :rfc_message_id,
                 :in_reply_to,
                 :references,
                 :text_parts,
                 :attachments,
                 :messages,
                 :metadata
               ])
    end

    test "rfc822 parts with empty content become nested messages with empty text" do
      # Gmail split the empty and the header-only message/rfc822 part of this
      # forward into nested parts with empty bodies.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_opaque")
      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", recorded)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert message.attachments == []

      assert [
               %{part_id: "1", filename: "empty.eml", headers: [], attachments: []} = empty,
               %{part_id: "2", filename: "headers-only.eml"} = headers_only
             ] = message.messages

      assert [%{part_id: "1.0", content: "", size: 0, decoded: true}] = empty.text_parts
      assert [%{part_id: "2.0", content: "", size: 0, decoded: true}] = headers_only.text_parts
      assert header(headers_only, "Subject") == "jcl-live headers-only original"
    end

    test "an attached forward without nested parts lists the part as a message/rfc822 attachment" do
      # Gmail split every message/rfc822 part the seed tried into nested parts:
      # a base64-encoded original (opaque.eml of the charset message), a part
      # with empty content (empty.eml) and a part with a header block only
      # (headers-only.eml). No recording therefore has one without nested
      # parts. This variant drops the nested parts of headers-only.eml from the
      # recorded forward.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_opaque")

      variant =
        update_in(recorded, ["payload", "parts"], fn parts ->
          Enum.map(parts, fn
            %{"partId" => "2"} = part -> Map.delete(part, "parts")
            part -> part
          end)
        end)

      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", variant)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert [%{part_id: "1", filename: "empty.eml"}] = message.messages

      assert [
               %{
                 part_id: "2",
                 filename: "headers-only.eml",
                 mime_type: "message/rfc822",
                 size: 258,
                 disposition: "attachment",
                 attachment_id: attachment_id
               }
             ] = message.attachments

      assert attachment_id ==
               get_in(recorded, ["payload", "parts", Access.at(2), "body", "attachmentId"])
    end

    test "fetches the windows-1252 body text that Gmail keeps behind an attachmentId" do
      # The format=full recording of the large-body message. In place of its
      # 3 MB attachments.get response, the test serves the one recorded for
      # notiz.txt of the conversation, ASCII text that windows-1252 decodes
      # the same, under the attachment ID of this recording.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_large_body")

      assert [
               %{"partId" => "0", "mimeType" => "text/plain", "filename" => "", "body" => body},
               %{"partId" => "1", "mimeType" => "text/html"}
             ] = recorded["payload"]["parts"]

      assert %{"attachmentId" => attachment_id, "size" => 3_149_652} = body
      refute Map.has_key?(body, "data")

      fetch =
        put_in(
          recording!("attachments_conversation"),
          ["request", "path"],
          "/gmail/v1/users/me/messages/#{recorded["id"]}/attachments/#{attachment_id}"
        )

      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", recorded)
      expect_attachment(fetch)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert message.text_parts == [
               %{
                 part_id: "0",
                 mime_type: "text/plain",
                 charset: "windows-1252",
                 size: 25,
                 content: "Kurze Notiz zum Termin.\r\n",
                 content_base64: nil,
                 encoding: "utf-8",
                 decoded: true
               },
               %{
                 part_id: "1",
                 mime_type: "text/html",
                 charset: "utf-8",
                 size: 80,
                 content:
                   "<p>Großer Textkörper in windows-1252, Marker <b>jcl-marker-large-body</b>.</p>",
                 content_base64: nil,
                 encoding: "utf-8",
                 decoded: true
               }
             ]

      assert message.attachments == []
      assert message.messages == []
    end

    test "fetches a text part stored behind an attachmentId inside an enclosed message" do
      # The large-body recording has its body text part behind an attachmentId
      # at the top level; no recording has one inside an enclosed message. This
      # variant gives the text/plain body of original.eml the shape of a large
      # body, with the attachment ID and the small response that
      # attachments.get was recorded with for inner.txt of the same message.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_attached")
      fetch = recording!("attachments_forward_attached")
      stored = %{"attachmentId" => attachment_id(fetch), "size" => 19}

      variant =
        update_in(
          recorded,
          part_path(["1", "1.0", "1.0.0", "1.0.0.0"]),
          &Map.put(&1, "body", stored)
        )

      expect_full("/gmail/v1/users/me/messages/#{recorded["id"]}", variant)
      expect_attachment(fetch)

      assert {:ok, %{message: %{messages: [original, _simple]}}} = read_message(recorded["id"])

      assert Enum.map(original.text_parts, &{&1.part_id, &1.content}) == [
               {"1.0.0.0", "Inner attachment.\r\n"},
               {"1.0.0.1",
                "<p>Attached original with marker <b>jcl-marker-forward-attached</b>.</p>"}
             ]

      assert [%{part_id: "1.0.1", filename: "inner.txt"}] = original.attachments
    end

    test "puts a fetched text part back in Gmail's part order, comparing part IDs as numbers" do
      # A variant of the recorded attachment message: three copies of its inline
      # text part 1 become parts 8, 9 and 10, and text part 2 takes the shape
      # of a large body, behind the attachment ID that attachments.get was
      # recorded with for notes.txt, which serves its small response. A
      # comparison of part IDs as strings would put 10 before 2.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_attachments")
      fetch = recording!("attachment_notes_latin9")
      parts = recorded["payload"]["parts"]
      text_part = Enum.find(parts, &(&1["partId"] == "1"))

      parts =
        Enum.map(parts, fn
          %{"partId" => "2"} = part ->
            %{part | "body" => %{"attachmentId" => attachment_id(fetch), "size" => 27}}

          part ->
            part
        end) ++ for(id <- ["8", "9", "10"], do: %{text_part | "partId" => id})

      expect_full(
        "/gmail/v1/users/me/messages/#{recorded["id"]}",
        put_in(recorded, ["payload", "parts"], parts)
      )

      expect_attachment(fetch)

      assert {:ok, %{message: message}} = read_message(recorded["id"])

      assert Enum.map(message.text_parts, & &1.part_id) ==
               ["0.0.0", "0.0.1", "1", "2", "8", "9", "10"]

      assert %{charset: "koi8-r", decoded: false, size: 27} =
               Enum.find(message.text_parts, &(&1.part_id == "2"))
    end
  end

  describe "google.gmail.thread.content.get" do
    test "returns the received mail, the sent reply without INBOX and the later answer in internalDate order" do
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", recorded)

      assert {:ok, %{thread: thread}} = read_thread(recorded["id"])

      assert thread.thread_id == recorded["id"]
      assert thread.history_id == recorded["historyId"]
      assert [received, reply, later] = thread.messages

      assert Enum.map(thread.messages, & &1.message_id) ==
               Enum.map(recorded["messages"], & &1["id"])

      dates = Enum.map(thread.messages, &String.to_integer(&1.internal_date))
      assert dates == Enum.sort(dates)

      assert "INBOX" in received.label_ids
      assert reply.label_ids == ["SENT"]
      assert "INBOX" in later.label_ids

      assert reply.in_reply_to == received.rfc_message_id
      assert later.in_reply_to == reply.rfc_message_id
      assert later.references == "#{received.rfc_message_id} #{reply.rfc_message_id}"

      assert [
               %{
                 part_id: "0",
                 content: "Ja, der Termin steht. Marker jcl-marker-conv-reply.\r\n" <> _
               },
               %{part_id: "1"}
             ] =
               reply.text_parts
    end

    test "orders messages by numeric internalDate and keeps Gmail's order for equal dates" do
      # Gmail returned the conversation in date order. These variants reorder
      # the recorded messages or change their internalDate.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [first, reply, later] = recorded["messages"]
      path = "/gmail/v1/users/me/threads/#{recorded["id"]}"

      # A 12-digit date is the smaller number but sorts last as a string.
      earliest = %{later | "internalDate" => "999999999999"}
      tied = %{reply | "internalDate" => first["internalDate"]}

      for {messages, expected} <- [
            {[later, reply, first], [first, reply, later]},
            {[first, reply, earliest], [earliest, first, reply]},
            {[tied, first, later], [tied, first, later]},
            {[first, tied, later], [first, tied, later]}
          ] do
        expect_full(path, %{recorded | "messages" => messages})

        assert {:ok, %{thread: thread}} = read_thread(recorded["id"])

        assert Enum.map(thread.messages, &{&1.message_id, &1.internal_date}) ==
                 Enum.map(expected, &{&1["id"], &1["internalDate"]})
      end
    end

    test "orders by an integer internalDate and returns it as a string" do
      # Gmail returned internalDate as a string in every recording. This variant
      # reverses the recorded messages and gives them their dates as integers.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")

      messages =
        recorded["messages"]
        |> Enum.reverse()
        |> Enum.map(&Map.update!(&1, "internalDate", fn date -> String.to_integer(date) end))

      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", %{
        recorded
        | "messages" => messages
      })

      assert {:ok, %{thread: thread}} = read_thread(recorded["id"])

      assert Enum.map(thread.messages, &{&1.message_id, &1.internal_date}) ==
               Enum.map(recorded["messages"], &{&1["id"], &1["internalDate"]})
    end

    test "a missing or non-numeric internalDate fails the read with :invalid_response" do
      # Every recorded message has a numeric internalDate. These variants drop
      # it from the recorded sent reply or replace it.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [first, reply, later] = recorded["messages"]

      for invalid <- [
            Map.delete(reply, "internalDate"),
            %{reply | "internalDate" => nil},
            %{reply | "internalDate" => ""},
            %{reply | "internalDate" => reply["internalDate"] <> ".5"}
          ] do
        expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", %{
          recorded
          | "messages" => [first, invalid, later]
        })

        assert invalid_response(read_thread(recorded["id"])) == %{message_id: reply["id"]}
      end
    end

    test "returns a body longer than its snippet whole" do
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [_first, _reply, %{"snippet" => snippet}] = recorded["messages"]
      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", recorded)

      assert {:ok, %{thread: %{messages: [_received, _sent, long]}}} = read_thread(recorded["id"])

      assert [%{part_id: "0", size: 55_272, decoded: true, content: content}] = long.text_parts
      assert byte_size(snippet) < 512
      assert byte_size(content) == 55_272
      assert String.starts_with?(content, "Danke. Anbei die Notizen, Grüße.\r\n")
      assert String.ends_with?(content, "Marker jcl-marker-conv-long-end.\r\n")
      assert [%{part_id: "1", filename: "notiz.txt"}] = long.attachments
    end

    test "fetches a text body stored behind an attachmentId once and no file attachment" do
      # Gmail delivered the 55 KB body of the later answer inline; only a large
      # body, like that of the large-body message, comes behind an
      # attachmentId. This variant gives the body text of the later answer that
      # shape, behind the attachment ID that attachments.get was recorded with
      # for its notiz.txt, which serves its small response. notiz.txt keeps the
      # attachment ID of the thread recording, so a fetch of the file
      # attachment would be a request the test does not expect.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      fetch = recording!("attachments_conversation")
      # Access.filter/1 in the path makes get_in/2 return a list.
      [notiz_id] = get_in(recorded, later_part_path("1") ++ ["body", "attachmentId"])
      assert is_binary(notiz_id)
      refute notiz_id == attachment_id(fetch)

      variant =
        put_in(recorded, later_part_path("0") ++ ["body"], %{
          "attachmentId" => attachment_id(fetch),
          "size" => 25
        })

      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", variant)
      expect_attachment(fetch)

      assert {:ok, %{thread: %{messages: [_received, _sent, later]}}} =
               read_thread(recorded["id"])

      assert later.text_parts == [
               %{
                 part_id: "0",
                 mime_type: "text/plain",
                 charset: "utf-8",
                 size: 25,
                 content: "Kurze Notiz zum Termin.\r\n",
                 content_base64: nil,
                 encoding: "utf-8",
                 decoded: true
               }
             ]

      assert [%{part_id: "1", filename: "notiz.txt", attachment_id: ^notiz_id}] =
               later.attachments
    end

    test "a failed part fetch fails the whole read" do
      # The variant of the previous test: the body text in the shape of a large
      # body, behind the attachment ID that attachments.get was recorded
      # rejecting.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      fetch = recording!("attachment_unknown_id")
      assert %{"status" => 400} = fetch

      variant =
        put_in(recorded, later_part_path("0") ++ ["body"], %{
          "attachmentId" => attachment_id(fetch),
          "size" => 25
        })

      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", variant)
      expect_attachment(fetch)

      assert {:error,
              %Connect.Error.ProviderError{
                provider: :google,
                status: 400,
                details: %{message: "Invalid attachment token"}
              } = error} = read_thread(recorded["id"])

      for text <- [inspect(error), inspect(Connect.Error.to_map(error))] do
        refute text =~ "jcl-marker"
        refute text =~ "Danke. Anbei"
      end
    end

    test "an attachments.get response without data fails the read" do
      # The variant of the fetch test above, served the attachments.get
      # response recorded for notiz.txt without its data field.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [_first, _reply, %{"id" => later_id}] = recorded["messages"]
      fetch = recording!("attachments_conversation")

      variant =
        put_in(recorded, later_part_path("0") ++ ["body"], %{
          "attachmentId" => attachment_id(fetch),
          "size" => 25
        })

      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", variant)
      expect_attachment(update_in(fetch, ["body"], &Map.delete(&1, "data")))

      assert invalid_response(read_thread(recorded["id"])) ==
               %{message_id: later_id, part_id: "0"}
    end

    test "names the addressing and threading headers and keeps repeated headers" do
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [_first, recorded_reply, _later] = recorded["messages"]
      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", recorded)

      assert {:ok, %{thread: %{messages: [_received, reply, _later]}}} =
               read_thread(recorded["id"])

      assert reply.headers ==
               Enum.map(
                 recorded_reply["payload"]["headers"],
                 &%{name: &1["name"], value: &1["value"]}
               )

      assert Enum.count(reply.headers, &(&1.name == "Received")) == 2

      assert %{
               from: "Person 2 <person-2@example.com>",
               to: "Person 1 <person-1@example.com>",
               subject: "Re: jcl-live conversation",
               date: "Fri, 30 Oct 2026 10:30:24 -0500",
               rfc_message_id: "<person-4@example.com>",
               in_reply_to: "<person-3@example.com>",
               references: "<person-3@example.com>",
               cc: nil,
               bcc: nil,
               reply_to: nil
             } = reply

      # The recordings carry no Cc, Bcc or Reply-To header. This variant
      # appends them to the recorded headers of the sent reply, with addresses
      # from the same recording, and a second To header.
      extra = [
        %{"name" => "CC", "value" => "Person 1 <person-1@example.com>"},
        %{"name" => "bcc", "value" => "person-3@example.com"},
        %{"name" => "Reply-To", "value" => "Person 2 <person-2@example.com>"},
        %{"name" => "To", "value" => "person-5@example.com"}
      ]

      variant =
        update_in(recorded, ["messages", Access.at(1), "payload", "headers"], &(&1 ++ extra))

      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", variant)

      assert {:ok, %{thread: %{messages: [_received, reply, _later]}}} =
               read_thread(recorded["id"])

      assert %{
               to: "Person 1 <person-1@example.com>",
               cc: "Person 1 <person-1@example.com>",
               bcc: "person-3@example.com",
               reply_to: "Person 2 <person-2@example.com>"
             } = reply

      assert Enum.filter(reply.headers, &(&1.name == "To")) == [
               %{name: "To", value: "Person 1 <person-1@example.com>"},
               %{name: "To", value: "person-5@example.com"}
             ]
    end

    test "a thread with more messages than max_messages fails without content" do
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      expect_full("/gmail/v1/users/me/threads/#{recorded["id"]}", recorded)

      assert {:error,
              %Connect.Error.ProviderError{
                reason: :thread_messages_exceeded,
                details: %{thread_id: thread_id, max_messages: 2, message_count: 3}
              } = error} = read_thread(recorded["id"], max_messages: 2)

      assert thread_id == recorded["id"]
      refute inspect(error) =~ "jcl-marker"
    end

    test "max_messages defaults to 100" do
      # A variant of the recorded conversation with 101 copies of its first
      # message.
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [first | _rest] = recorded["messages"]
      long_thread = %{recorded | "messages" => List.duplicate(first, 101)}
      path = "/gmail/v1/users/me/threads/#{recorded["id"]}"

      expect_full(path, long_thread)

      assert {:error,
              %Connect.Error.ProviderError{
                reason: :thread_messages_exceeded,
                details: %{max_messages: 100, message_count: 101}
              }} = read_thread(recorded["id"])

      expect_full(path, %{long_thread | "messages" => List.duplicate(first, 100)})

      assert {:ok, %{thread: %{messages: messages}}} = read_thread(recorded["id"])
      assert length(messages) == 100
    end
  end

  describe "invalid content responses" do
    # Variants of the recordings in shapes Gmail did not return. Each fails
    # with :invalid_response and details that name IDs only.

    test "a message or thread without an id" do
      message = LiveSmoke.fixture!(:gmail, "message_full_forward_inline")
      thread = LiveSmoke.fixture!(:gmail, "thread_full_conversation")

      for variant <- [Map.delete(message, "id"), %{message | "id" => ""}] do
        expect_full("/gmail/v1/users/me/messages/#{message["id"]}", variant)
        assert invalid_response(read_message(message["id"])) == %{}
      end

      for variant <- [Map.delete(thread, "id"), %{thread | "id" => ""}] do
        expect_full("/gmail/v1/users/me/threads/#{thread["id"]}", variant)
        assert invalid_response(read_thread(thread["id"])) == %{}
      end
    end

    test "a thread whose messages are not a list of maps" do
      thread = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      [first | _rest] = thread["messages"]

      for messages <- [nil, first, [first, first["id"]]] do
        expect_full("/gmail/v1/users/me/threads/#{thread["id"]}", %{
          thread
          | "messages" => messages
        })

        assert invalid_response(read_thread(thread["id"])) == %{thread_id: thread["id"]}
      end
    end

    test "a message or thread that the content struct rejects" do
      message = LiveSmoke.fixture!(:gmail, "message_full_forward_inline")
      thread = LiveSmoke.fixture!(:gmail, "thread_full_conversation")

      expect_full("/gmail/v1/users/me/messages/#{message["id"]}", %{message | "threadId" => 42})
      assert invalid_response(read_message(message["id"])) == %{message_id: message["id"]}

      for history_id <- [true, %{"id" => thread["historyId"]}] do
        expect_full("/gmail/v1/users/me/threads/#{thread["id"]}", %{
          thread
          | "historyId" => history_id
        })

        assert invalid_response(read_thread(thread["id"])) == %{thread_id: thread["id"]}
      end
    end
  end

  test "metadata reads still request format=metadata" do
    for {action_id, input, path} <- [
          {"google.gmail.message.get", %{message_id: "msg"}, "/gmail/v1/users/me/messages/msg"},
          {"google.gmail.thread.get", %{thread_id: "thread"}, "/gmail/v1/users/me/threads/thread"}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == path
        assert conn.query_params == %{"format" => "metadata"}
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Connect.Error.ProviderError{}} = invoke(action_id, input)
    end
  end

  defp expect_full(path, body) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == path
      assert conn.query_params == %{"format" => "full"}

      Req.Test.json(conn, body)
    end)
  end

  defp expect_attachment(%{"request" => %{"path" => path}, "status" => status, "body" => body}) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == path
      assert conn.query_params == %{}

      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(body)
    end)
  end

  # A whole recording: the request, the status and the body.
  defp recording!(name) do
    ["test", "fixtures", "gmail", "recorded", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp attachment_id(%{"request" => %{"path" => path}}),
    do: path |> String.split("/attachments/") |> List.last()

  # The Access path of the part with each ID in turn, from the payload down.
  defp part_path(part_ids),
    do: [
      "payload"
      | Enum.flat_map(part_ids, &["parts", Access.filter(fn part -> part["partId"] == &1 end)])
    ]

  defp later_part_path(part_id), do: ["messages", Access.at(2) | part_path([part_id])]

  defp read_message(message_id),
    do: invoke("google.gmail.message.content.get", %{message_id: message_id})

  defp read_thread(thread_id, opts \\ []),
    do: invoke("google.gmail.thread.content.get", Map.new([{:thread_id, thread_id} | opts]))

  defp invoke(action_id, input) do
    {context, lease} = context_and_lease()

    Connect.invoke(Gmail.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  # The details of an :invalid_response error, which never quote message data.
  defp invalid_response(result) do
    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: details
            } = error} = result

    refute inspect(error) =~ "jcl-marker"
    details
  end

  defp header(%{headers: headers}, name) do
    Enum.find_value(headers, fn header -> if header.name == name, do: header.value end)
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: [@readonly_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"},
        scopes: [@readonly_scope]
      })

    {context, lease}
  end
end
