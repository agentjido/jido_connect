defmodule Jido.Connect.Gmail.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Client
  alias Jido.Connect.Gmail.MIME.Traversal

  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @max_pages 20

  # Prepared data of the test account: GOOGLE_GMAIL_QUERY matches exactly these
  # messages. The seed script restores them, possibly under new IDs.
  @query_matches 5
  @query_inbox_matches 3
  @query_archived_matches 2

  # The body text of the large-body message, which the seed script generates
  # the same on every run: its size in windows-1252 and the SHA-256 of its
  # UTF-8 form.
  @large_body_size 3_149_652
  @large_body_sha256 "f58a864cb155e8d126e6b13883d36eec73de34aa318f849e5fa2a000752df70f"

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "reads the mailbox profile", %{env: env} do
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, "profile")

    assert {:ok, profile} = Client.get_profile(%{}, env["GOOGLE_ACCESS_TOKEN"])
    assert is_map(profile)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_QUERY"])
  test "a query search pages through inbox and archived messages", %{env: env} do
    {context, lease} = read_grant(env["GOOGLE_ACCESS_TOKEN"])
    query = env["GOOGLE_GMAIL_QUERY"]

    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, "messages_list_query")
    pages = page_through(%{query: query, page_size: 1}, context, lease)

    assert Enum.all?(pages, &(length(&1.messages) <= 1))

    match_ids = pages |> Enum.flat_map(& &1.messages) |> Enum.map(& &1.message_id)
    assert length(match_ids) == @query_matches
    assert length(match_ids) == length(Enum.uniq(match_ids))

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "messages_list_query_inbox"
    )

    assert {:ok, %{messages: inbox_messages} = inbox_page} =
             invoke_list(%{query: query, label_ids: ["INBOX"]}, context, lease)

    assert Map.get(inbox_page, :next_page_token) == nil

    matched = MapSet.new(match_ids)
    inbox = MapSet.new(inbox_messages, & &1.message_id)
    archived = MapSet.difference(matched, inbox)

    assert MapSet.size(inbox) == @query_inbox_matches
    assert MapSet.size(archived) == @query_archived_matches
    assert MapSet.subset?(inbox, matched)
  end

  @tag env!(["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN", "GOOGLE_GMAIL_QUERY"])
  test "Google rejects a query search under the metadata-only grant", %{env: env} do
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "messages_list_query_metadata_scope"
    )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :google,
              status: 403,
              details: %{message: "Metadata scope does not support 'q' parameter"}
            }} =
             Client.list_messages(
               %{query: env["GOOGLE_GMAIL_QUERY"], page_size: 1},
               env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"]
             )
  end

  # The format=full payloads of the prepared messages are the fixtures of
  # mime_traversal_test.exs and content_test.exs. Each test records exactly
  # one response, so the recorder sanitizes its body with fresh placeholders,
  # as LiveSmoke.sanitize/2 does with the live body below; the comparison
  # therefore sees the same addresses and names on both sides. Gmail issues
  # a new attachmentId with every response, so only the presence of an
  # attachment ID is compared.

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"])
  test "traverses the single-part message like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]}",
      "message_full_single_part"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"])
  test "traverses the nested attachment message like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"]}",
      "message_full_attachments"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_ATTACHED_ID"])
  test "traverses the forward with attached messages like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_FORWARD_ATTACHED_ID"]}",
      "message_full_forward_attached"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_CHARSET_MESSAGE_ID"])
  test "traverses the charset message like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_CHARSET_MESSAGE_ID"]}",
      "message_full_charsets"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_LARGE_BODY_ID"])
  test "traverses the large-body message like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_LARGE_BODY_ID"]}",
      "message_full_large_body"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"])
  test "traverses the unnamed-attachment message like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/messages/#{env["GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"]}",
      "message_full_unnamed_attachments"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_THREAD_ID"])
  test "traverses every message of the conversation like its recording", %{env: env} do
    assert_traversal_matches_recording(
      env["GOOGLE_ACCESS_TOKEN"],
      "/gmail/v1/users/me/threads/#{env["GOOGLE_GMAIL_THREAD_ID"]}",
      "thread_full_conversation"
    )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"])
  test "attachments.get returns the original ISO-8859-15 bytes of notes.txt", %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"]

    # Not recorded: the attachment ID comes from this response, and
    # message_full_attachments already holds its recording.
    assert {:ok, %Req.Response{status: 200, body: %{"payload" => payload}}} =
             access_token
             |> Client.Transport.request()
             |> Req.get(
               url: "/gmail/v1/users/me/messages/#{message_id}",
               params: [format: "full"]
             )

    assert {:ok, %{attachments: attachments}} = Traversal.traverse(payload)

    assert %{filename: "notes.txt", size: size, attachment_id: attachment_id} =
             Enum.find(attachments, &(&1.part_id == "3"))

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "attachment_notes_latin9"
    )

    assert {:ok, %Gmail.Attachment{data: data}} =
             Client.get_attachment(
               %{message_id: message_id, attachment_id: attachment_id},
               access_token
             )

    assert byte_size(Base.url_decode64!(data, padding: false)) == size

    assert {:ok, %{content: "Notizen: € Œ œ Š š Ž ž Ÿ.\r\n", decoded: true}} =
             Traversal.decode_external_text_part(
               %{part_id: "3", mime_type: "text/plain", charset: "iso-8859-15"},
               data
             )
  end

  # The content actions. Each test runs an action live and on the recorded
  # responses and compares the two results: message order, a digest of every
  # text part, all headers, nested messages and the attachment manifest. Live
  # responses pass through LiveSmoke.sanitize/2 first, as their recordings did.
  # Label and history IDs change with the mailbox and are left out. Attachment
  # digests compare the bytes that google.gmail.message.attachment.get returns
  # for each manifest entry with their recordings. The seed keeps manifest
  # entries synthetic; an attached original names real addresses inside its
  # base64 data, so its bytes are not fetched or recorded.

  defmodule SanitizingClient do
    @moduledoc false
    # The Gmail client with content responses sanitized like their recordings.

    alias Jido.Connect.Gmail.Client
    alias Jido.Connect.TestSupport.LiveSmoke

    def get_message_content(params, access_token) do
      with {:ok, body} <- Client.get_message_content(params, access_token),
           do: {:ok, LiveSmoke.sanitize(body)}
    end

    def get_thread_content(params, access_token) do
      with {:ok, body} <- Client.get_thread_content(params, access_token),
           do: {:ok, LiveSmoke.sanitize(body)}
    end

    defdelegate get_attachment(params, access_token), to: Client
  end

  defmodule RecordedClient do
    @moduledoc false
    # Serves the format=full recording with the requested ID.

    alias Jido.Connect.TestSupport.LiveSmoke

    @messages ~w(message_full_forward_inline message_full_forward_attached
                 message_full_forward_opaque)
    @threads ~w(thread_full_conversation)

    def get_message_content(%{message_id: id}, _access_token), do: recording(@messages, id)
    def get_thread_content(%{thread_id: id}, _access_token), do: recording(@threads, id)

    def get_attachment(_params, _access_token),
      do: {:error, Jido.Connect.Error.provider("attachments are not served", provider: :google)}

    defp recording(names, id) do
      Enum.find_value(names, {:error, "no recording of #{id}; record it again"}, fn name ->
        path = Path.join(["test", "fixtures", "gmail", "recorded", "#{name}.json"])

        with true <- File.exists?(path),
             %{"id" => ^id} = body <- LiveSmoke.fixture!(:gmail, name),
             do: {:ok, body},
             else: (_other -> nil)
      end)
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_THREAD_ID"])
  test "thread.content.get returns the conversation like its recording", %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    input = %{thread_id: env["GOOGLE_GMAIL_THREAD_ID"]}

    # Recorded by "traverses every message of the conversation like its recording".
    live = invoke_content!("google.gmail.thread.content.get", input, access_token, :thread)
    recorded = recorded_content!("google.gmail.thread.content.get", input, :thread)

    assert [received, sent, later] = live.messages
    assert "INBOX" in received.label_ids
    assert "SENT" in sent.label_ids
    refute "INBOX" in sent.label_ids
    assert String.to_integer(sent.internal_date) <= String.to_integer(later.internal_date)
    assert byte_size(hd(later.text_parts).content) == 55_272
    assert digest_view(live) == digest_view(recorded)

    assert_attachment_digests(live.messages, access_token, "attachments_conversation")
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_INLINE_ID"])
  test "message.content.get returns the inline forward like its recording", %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    input = %{message_id: env["GOOGLE_GMAIL_FORWARD_INLINE_ID"]}

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "message_full_forward_inline"
    )

    live = invoke_content!("google.gmail.message.content.get", input, access_token, :message)
    recorded = recorded_content!("google.gmail.message.content.get", input, :message)

    assert [%{mime_type: "text/plain"} = plain, %{mime_type: "text/html"} = html] =
             live.text_parts

    for part <- [plain, html] do
      assert part.content =~ "---------- Forwarded message ---------"
      assert part.content =~ "original.sender@example.org"
      assert part.content =~ "jcl-marker-forward-inline"
    end

    assert live.messages == []
    assert digest_view(live) == digest_view(recorded)

    assert_attachment_digests([live], access_token, "attachments_forward_inline")
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_ATTACHED_ID"])
  test "message.content.get returns the attached forward like its recording", %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    input = %{message_id: env["GOOGLE_GMAIL_FORWARD_ATTACHED_ID"]}

    # Recorded by "traverses the forward with attached messages like its recording".
    live = invoke_content!("google.gmail.message.content.get", input, access_token, :message)
    recorded = recorded_content!("google.gmail.message.content.get", input, :message)

    assert [original, simple] = live.messages
    assert original_header(original, "Subject") == "jcl-live attached original"
    assert original_header(original, "From") =~ "@example.com>"
    assert original_header(original, "Date") != nil
    assert original_header(simple, "Subject") == "jcl-live simple original"
    assert digest_view(live) == digest_view(recorded)

    assert_attachment_digests([live], access_token, "attachments_forward_attached")
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_OPAQUE_ID"])
  test "message.content.get returns the forward of empty originals like its recording",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    input = %{message_id: env["GOOGLE_GMAIL_FORWARD_OPAQUE_ID"]}

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "message_full_forward_opaque"
    )

    live = invoke_content!("google.gmail.message.content.get", input, access_token, :message)
    recorded = recorded_content!("google.gmail.message.content.get", input, :message)

    # Gmail splits an rfc822 part with empty content, and one with a header
    # block only, into a nested message with an empty text part.
    assert live.attachments == []

    assert [
             %{part_id: "1", filename: "empty.eml", text_parts: [%{part_id: "1.0", content: ""}]},
             %{
               part_id: "2",
               filename: "headers-only.eml",
               text_parts: [%{part_id: "2.0", content: ""}]
             }
           ] = live.messages

    assert digest_view(live) == digest_view(recorded)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_LARGE_BODY_ID"])
  test "message.content.get fetches the windows-1252 body that Gmail keeps behind an attachmentId",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_LARGE_BODY_ID"]

    # Not recorded: attachments.get returns the 3 MB body as about 4 MB of
    # data. "traverses the large-body message like its recording" records the
    # format=full response.
    assert {:ok, %{"payload" => %{"parts" => parts}}} =
             Client.get_message_content(%{message_id: message_id}, access_token)

    assert %{"mimeType" => "text/plain", "body" => %{"attachmentId" => _id} = body} =
             Enum.find(parts, &(&1["partId"] == "0"))

    assert body["size"] == @large_body_size
    refute Map.has_key?(body, "data")

    {context, lease} = read_grant(access_token)

    assert {:ok, %{message: message}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.message.content.get",
               %{message_id: message_id},
               context: context,
               credential_lease: lease
             )

    # Compared as digests, so a failure does not print 3 MB of text.
    assert [
             %{
               part_id: "0",
               mime_type: "text/plain",
               charset: "windows-1252",
               size: @large_body_size,
               decoded: true,
               content: {:sha256, @large_body_sha256}
             },
             %{part_id: "1", mime_type: "text/html", decoded: true}
           ] = digest_view(message.text_parts)

    assert message.attachments == []
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_THREAD_ID"])
  test "attachments.get rejects an unknown attachment ID", %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]

    # Not recorded: the conversation already has its recording.
    assert {:ok, %{"messages" => [_first, _reply, %{"id" => message_id}]}} =
             Client.get_thread_content(%{thread_id: env["GOOGLE_GMAIL_THREAD_ID"]}, access_token)

    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, "attachment_unknown_id")

    assert {:error, %Connect.Error.ProviderError{provider: :google, status: status}} =
             Client.get_attachment(
               %{message_id: message_id, attachment_id: "jcl-unknown-attachment-id"},
               access_token
             )

    assert status in 400..499
  end

  # google.gmail.message.attachment.content.get. Each test compares the bytes
  # with the files that the seed script built, by byte count and SHA-256 from
  # its manifest. A recording takes every later response of its test, so the
  # unrecorded calls come first. Each recorded call writes a format=full
  # response and, for data behind an attachmentId, the attachments.get
  # response for an ID from it, as attachment_content_<name>.json and .2.json.

  @attachment_files [
    {"0.1", "logo.png", 73, "805924e65dff89ccbac4046a6995a73622a878f5ff9ec17678b4bc33ca55ea12"},
    {"3", "notes.txt", 27, "f35e372236d8d39aec9fd80e718e92c8b1e8aa136907ba55b4411393a204187e"},
    {"4", "data.bin", 4096, "d41d438c379110c7f7b2c561b1f04f26c1b4549110791f8e022f48974280c13e"},
    {"5", "empty.bin", 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
    {"6", "report.csv", 16, "15a12746b2a7f4d887a8e1cf6c0d603c419a980b097d79e1aa13b0f613cc3984"},
    {"7", "report.csv", 23, "504c3f66763b328252c334fa6e3234a7469c526a02e79d4470d3c71abfd19fcf"}
  ]

  @recorded_attachments %{
    "4" => "attachment_content_data_bin",
    "7" => "attachment_content_report_csv"
  }

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"])
  test "attachment.content.get returns every attachment of the prepared message byte-exact",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"]

    # Not recorded: message_full_attachments holds this response.
    assert {:ok, %{"payload" => payload}} =
             Client.get_message_content(%{message_id: message_id}, access_token)

    # The manifest lists exactly the known files; Gmail keeps empty.bin inline.
    assert {:ok, %{attachments: manifest}} = Traversal.traverse(payload)
    assert Enum.map(manifest, & &1.part_id) == Enum.map(@attachment_files, &elem(&1, 0))
    assert [%{part_id: "5"}] = Enum.filter(manifest, &is_nil(&1.attachment_id))

    {recorded, unrecorded} =
      Enum.split_with(@attachment_files, &Map.has_key?(@recorded_attachments, elem(&1, 0)))

    for {part_id, filename, size, sha256} <- unrecorded ++ recorded do
      case Map.fetch(@recorded_attachments, part_id) do
        {:ok, name} -> LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, name)
        :error -> :ok
      end

      attachment = attachment_content!(message_id, part_id, access_token)

      assert %{message_id: ^message_id, part_id: ^part_id, filename: ^filename, size: ^size} =
               attachment

      assert is_nil(attachment.attachment_id) == (part_id == "5")
      assert digest(attachment.data) == {size, sha256}
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_ATTACHED_ID"])
  test "attachment.content.get returns an attached original and an attachment inside it",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_FORWARD_ATTACHED_ID"]

    # Not recorded and compared by size only: the bytes of original.eml name
    # the real recipient in its To header.
    original = attachment_content!(message_id, "1", access_token)

    assert Map.take(original, [:part_id, :filename, :mime_type, :size]) ==
             %{part_id: "1", filename: "original.eml", mime_type: "message/rfc822", size: 1072}

    assert is_binary(original.attachment_id)
    assert byte_size(Base.url_decode64!(original.data, padding: false)) == 1072

    # inner.txt sits in the multipart/mixed part of the original.
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "attachment_content_forward_inner"
    )

    inner = attachment_content!(message_id, "1.0.1", access_token)
    assert %{part_id: "1.0.1", filename: "inner.txt", size: 19} = inner

    assert digest(inner.data) ==
             {19, "82ba71b14a7df9e97396cfaab882b5934b0e70f0ac4011ce46e492d2bc141fd9"}
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_OPAQUE_ID"])
  test "attachment.content.get returns the empty original inline and the header-only one",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_FORWARD_OPAQUE_ID"]

    # Not recorded: message_full_forward_opaque holds this response.
    assert %{part_id: "1", filename: "empty.eml", size: 0, attachment_id: nil, data: ""} =
             attachment_content!(message_id, "1", access_token)

    # The header-only original names synthetic addresses only. The seed
    # manifest has no digest for it, so the bytes are compared with their
    # recording.
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :gmail,
      "attachment_content_headers_only"
    )

    headers_only = attachment_content!(message_id, "2", access_token)

    assert %{part_id: "2", filename: "headers-only.eml", mime_type: "message/rfc822", size: 258} =
             headers_only

    %{"data" => recorded} = LiveSmoke.fixture!(:gmail, "attachment_content_headers_only.2")
    assert digest(headers_only.data) == digest(recorded)
  end

  # The unnamed parts of GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID that Gmail
  # returns with their original bytes: the binary parts 2, 4 and 7 behind an
  # attachmentId, the UTF-8 part 8 and the ASCII-only ISO-8859-1 part 9 inline.
  @unnamed_files [
    {"2", 64, "c39e13bbb05726a3c0747d3ca54c27e3f86bc10a1d3754cd031bd1ca7256c8ed"},
    {"4", 73, "805924e65dff89ccbac4046a6995a73622a878f5ff9ec17678b4bc33ca55ea12"},
    {"7", 600, "9e1c936f1a61671484eed46c09637ce38afa0097dfee58c55926819db01a7d0a"},
    {"8", 50, "4b015575621b891b45221c6ee01374ac7c887b90829023af49423c99f29fba60"},
    {"9", 26, "242fd88425f231f1302026950fc51f8f904a6bbd198647b03aa6509a5194d12b"}
  ]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"])
  test "attachment.content.get returns unnamed attachments only with their original bytes",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"]
    {context, lease} = read_grant(access_token)

    # Not recorded: "traverses the unnamed-attachment message like its
    # recording" records the format=full response.
    for {part_id, size, sha256} <- @unnamed_files do
      attachment = attachment_content!(message_id, part_id, access_token)

      assert %{part_id: ^part_id, filename: nil, size: ^size} = attachment
      assert is_nil(attachment.attachment_id) == part_id in ["8", "9"]
      assert digest(attachment.data) == {size, sha256}
    end

    # Gmail returns the ISO-8859-1, Windows-1252 and UTF-16LE text inline and
    # converted to UTF-8; part 6 keeps its length.
    for part_id <- ["1", "3", "5", "6"] do
      assert {:error,
              %Connect.Error.ProviderError{
                reason: :attachment_converted,
                details: %{part_id: ^part_id}
              }} = invoke_attachment_content(message_id, part_id, context, lease)
    end

    assert {:error, %Connect.Error.ValidationError{reason: :not_an_attachment}} =
             invoke_attachment_content(message_id, "0", context, lease)
  end

  # google.gmail.message.changed. The polls run on a metadata-only lease with
  # the gmail.metadata token. The write steps run through the write actions on
  # the full grant, prepared and committed with a host authorization as a
  # host would run them, and before any recording starts, so the recordings
  # hold only the poll under test.

  @req_options {:jido_connect_google, :google_req_options}
  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"
  @mail_scope "https://mail.google.com/"

  # Gmail's history can trail a write. A wait for it polls at most this often,
  # 2 s apart, and so sleeps at most 28 s; a test that waits sets its timeout
  # for all of its waits.
  @history_polls 15

  @tag env!(["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"])
  test "the change poll turns a history ID older than Gmail's history into a checkpoint reset",
       %{env: env} do
    LiveSmoke.record(@req_options, :gmail, "message_changed_expired")

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
    grant = write_grant(env["GOOGLE_ACCESS_TOKEN"])
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
        assert {:ok, _output} = commit(grant, action_id, input)

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
    LiveSmoke.record(@req_options, :gmail, "message_changed_history")

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
    grant = write_grant(access_token)

    %{"id" => message_id} =
      insert_message!(access_token, [{"Subject", "jcl-live trash #{run_id()}"}], ["INBOX"])

    assert {:ok, %{message: %{thread_id: thread_id, label_ids: labels}}} =
             invoke(grant, "google.gmail.message.get", %{message_id: message_id})

    assert "INBOX" in labels
    refute "TRASH" in labels

    assert {:ok, %{thread: %{thread_id: ^thread_id, messages: [%{message_id: ^message_id}]}}} =
             invoke(grant, "google.gmail.thread.get", %{thread_id: thread_id})

    LiveSmoke.record(@req_options, :gmail, "message_trash")

    assert {:ok, %{message: %{message_id: ^message_id, label_ids: trashed}}} =
             commit(grant, "google.gmail.message.trash", %{message_id: message_id})

    assert "TRASH" in trashed
    refute "INBOX" in trashed

    LiveSmoke.record(@req_options, :gmail, "message_untrash")

    assert {:ok, %{message: %{message_id: ^message_id, label_ids: restored}}} =
             commit(grant, "google.gmail.message.untrash", %{message_id: message_id})

    refute "TRASH" in restored
    refute "INBOX" in restored

    LiveSmoke.record(@req_options, :gmail, "thread_trash")

    assert {:ok,
            %{
              thread: %{
                thread_id: ^thread_id,
                messages: [%{message_id: ^message_id, label_ids: thread_trashed}]
              }
            }} = commit(grant, "google.gmail.thread.trash", %{thread_id: thread_id})

    assert "TRASH" in thread_trashed

    LiveSmoke.record(@req_options, :gmail, "thread_untrash")

    assert {:ok,
            %{
              thread: %{
                thread_id: ^thread_id,
                messages: [%{message_id: ^message_id, label_ids: thread_restored}]
              }
            }} = commit(grant, "google.gmail.thread.untrash", %{thread_id: thread_id})

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

    run = run_id()
    subject = "jcl-live received #{run}"
    original_header_id = "<jcl-live-received-#{run}-1@example.org>"

    %{"id" => original_id, "threadId" => thread_id} =
      insert_message!(
        access_token,
        [{"Subject", subject}, {"Message-ID", original_header_id}],
        ["INBOX", "UNREAD"]
      )

    reply =
      insert_message!(
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
    LiveSmoke.record(@req_options, :gmail, "message_received_history")

    assert {:ok, %{signals: recorded, checkpoint: checkpoint}} =
             poll_received(start, metadata_token)

    assert received(recorded, message_ids) == received(signals, message_ids)

    assert String.to_integer(checkpoint) >= String.to_integer(next)
  end

  # google.gmail.message.labels.apply on the archive pair: two messages of one
  # thread, both in the inbox. Each test checks the pair before its first
  # write and, when it exits, restores the labels it changes, also after a
  # failed assertion, so the tests leave the pair as they found it.

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID", "GOOGLE_GMAIL_LABEL_ID"])
  @tag write!(:google)
  test "labels.apply adds and removes the test label and UNREAD on one message of the archive pair",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    grant = write_grant(access_token)
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
                 commit(
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
    grant = write_grant(access_token)
    message_id = env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]

    {thread_id, pair} = archive_pair!(grant, message_id)
    labels = pair[message_id]
    restore_labels_on_exit(access_token, message_id, labels, ["INBOX"])
    archived = labels -- ["INBOX"]

    # The answer to the archive request alone; prepare does not call Gmail.
    LiveSmoke.record(@req_options, :gmail, "message_modify_archive")

    assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = changed}} =
             commit(grant, "google.gmail.message.labels.apply", %{
               message_id: message_id,
               add_label_ids: [],
               remove_label_ids: ["INBOX"]
             })

    assert Enum.sort(changed.label_ids) == archived

    # The archived message stays retrievable with its other labels and its
    # read state; its sibling keeps every label, INBOX included.
    LiveSmoke.record(@req_options, :gmail, "message_metadata_archived")

    assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = read_back}} =
             invoke(grant, "google.gmail.message.get", %{message_id: message_id})

    assert Enum.sort(read_back.label_ids) == archived
    assert "UNREAD" in read_back.label_ids == "UNREAD" in labels

    LiveSmoke.record(@req_options, :gmail, "thread_metadata_archive_pair")
    assert thread_labels(grant, thread_id) == %{pair | message_id => archived}
  end

  defp invoke(%{context: context, lease: lease}, action_id, input) do
    Connect.invoke(Gmail.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  # Reads the archive pair through the read actions and checks it before a
  # write: the thread of `message_id` holds two messages, both in the inbox
  # and neither in Trash. Returns the thread ID and the sorted labels by
  # message ID.
  defp archive_pair!(grant, message_id) do
    assert {:ok, %{message: %{message_id: ^message_id, thread_id: thread_id}}} =
             invoke(grant, "google.gmail.message.get", %{message_id: message_id})

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
             invoke(grant, "google.gmail.thread.get", %{thread_id: thread_id})

    Map.new(messages, &{&1.message_id, Enum.sort(&1.label_ids)})
  end

  # Setup and cleanup call the Gmail API directly, outside the connector and
  # the recorder.

  @gmail_api "https://gmail.googleapis.com/gmail/v1/users/me"

  defp gmail_api(method, path, access_token, opts \\ []) do
    Req.request!(
      [method: method, url: @gmail_api <> path, auth: {:bearer, access_token}, retry: false] ++
        opts
    )
  end

  # Inserts a plain-text message with synthetic example.org addresses and
  # `headers` through messages.insert, which files it like received mail
  # without sending it, and deletes it for good when the test exits.
  defp insert_message!(access_token, headers, label_ids, thread_id \\ nil) do
    envelope = [
      {"From", "jcl-live.sender@example.org"},
      {"To", "jcl-live.recipient@example.org"},
      {"Date", Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S +0000")}
    ]

    mime = [{"MIME-Version", "1.0"}, {"Content-Type", ~s(text/plain; charset="utf-8")}]

    header_block =
      Enum.map_join(envelope ++ headers ++ mime, &"#{elem(&1, 0)}: #{elem(&1, 1)}\r\n")

    raw = header_block <> "\r\nSynthetic message of a jcl-live check.\r\n"

    body = %{"raw" => Base.url_encode64(raw), "labelIds" => label_ids}
    body = if thread_id, do: Map.put(body, "threadId", thread_id), else: body

    assert %{status: 200, body: %{"id" => message_id} = message} =
             gmail_api(:post, "/messages", access_token, json: body)

    on_exit(fn -> delete_message!(access_token, message_id) end)
    message
  end

  defp delete_message!(access_token, message_id) do
    case gmail_api(:delete, "/messages/#{message_id}", access_token) do
      %{status: status} when status in 200..299 or status == 404 ->
        :ok

      %{status: status} ->
        raise "cleanup could not delete live Gmail message #{message_id}: HTTP #{status}"
    end
  end

  # When the test exits, puts back the labels of `touched` that `message_id`
  # had in `label_ids` and removes those it did not have.
  defp restore_labels_on_exit(access_token, message_id, label_ids, touched) do
    on_exit(fn ->
      current =
        case gmail_api(:get, "/messages/#{message_id}?format=minimal", access_token) do
          %{status: 200, body: body} -> Map.get(body, "labelIds", [])
          %{status: status} -> raise "cleanup could not read #{message_id}: HTTP #{status}"
        end

      add = for id <- touched, id in label_ids, id not in current, do: id
      remove = for id <- touched, id in current, id not in label_ids, do: id

      if add != [] or remove != [] do
        body = %{"addLabelIds" => add, "removeLabelIds" => remove}

        case gmail_api(:post, "/messages/#{message_id}/modify", access_token, json: body) do
          %{status: 200} -> :ok
          %{status: status} -> raise "cleanup could not relabel #{message_id}: HTTP #{status}"
        end
      end
    end)
  end

  defp run_id, do: Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

  defp received(signals, message_ids), do: Enum.filter(signals, &(&1.message_id in message_ids))

  defp poll_received(checkpoint, metadata_token) do
    {context, lease} = grant(metadata_token, [@metadata_scope])

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
    {context, lease} = grant(metadata_token, [@metadata_scope])

    Connect.poll(Gmail.integration(), "google.gmail.message.changed", config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp write_grant(access_token) do
    {context, lease} = grant(access_token, [@modify_scope, @mail_scope])
    %{context: context, lease: lease}
  end

  defp commit(%{context: context, lease: lease}, action_id, input) do
    opts = [context: context, credential_lease: lease]

    with {:ok, prepared} <- Connect.prepare(Gmail.integration(), action_id, input, opts) do
      Connect.commit(
        Gmail.integration(),
        prepared,
        input,
        opts ++
          [
            execution_authorization: %{prepared_action_id: prepared.id},
            authorization_validator: &authorize/4
          ]
      )
    end
  end

  defp authorize(%{prepared_action_id: id}, %{id: id}, _context, _validator_context), do: :ok
  defp authorize(_evidence, _prepared, _context, _validator_context), do: :error

  defp attachment_content!(message_id, part_id, access_token) do
    {context, lease} = read_grant(access_token)

    assert {:ok, %{attachment: attachment}} =
             invoke_attachment_content(message_id, part_id, context, lease)

    attachment
  end

  defp invoke_attachment_content(message_id, part_id, context, lease) do
    Connect.invoke(
      Gmail.integration(),
      "google.gmail.message.attachment.content.get",
      %{message_id: message_id, part_id: part_id},
      context: context,
      credential_lease: lease
    )
  end

  defp digest(data) do
    bytes = Base.url_decode64!(data, padding: false)
    {byte_size(bytes), sha256(bytes)}
  end

  defp invoke_content!(action_id, input, access_token, key) do
    {context, lease} = read_grant(access_token)
    lease = %{lease | fields: Map.put(lease.fields, :gmail_client, SanitizingClient)}

    assert {:ok, %{^key => content}} =
             Connect.invoke(Gmail.integration(), action_id, input,
               context: context,
               credential_lease: lease
             )

    content
  end

  defp recorded_content!(action_id, input, key) do
    {context, lease} = read_grant("recorded")
    lease = %{lease | fields: Map.put(lease.fields, :gmail_client, RecordedClient)}

    assert {:ok, %{^key => content}} =
             Connect.invoke(Gmail.integration(), action_id, input,
               context: context,
               credential_lease: lease
             )

    content
  end

  # Fetches every manifest entry of `messages`, nested messages included, with
  # google.gmail.message.attachment.get and compares the digests of the bytes
  # with the recordings `<name>.json`, `<name>.2.json` and so on.
  defp assert_attachment_digests(messages, access_token, name) do
    entries =
      Enum.flat_map(messages, fn message ->
        Enum.map(manifest_entries(message), &{message.message_id, &1})
      end)

    assert entries != []
    {context, lease} = read_grant(access_token)
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, name)

    live =
      for {message_id, entry} <- entries do
        assert {:ok, %{attachment: %{data: data}}} =
                 Connect.invoke(
                   Gmail.integration(),
                   "google.gmail.message.attachment.get",
                   %{message_id: message_id, attachment_id: entry.attachment_id},
                   context: context,
                   credential_lease: lease
                 )

        bytes = Base.url_decode64!(data, padding: false)
        assert byte_size(bytes) == entry.size
        {entry.part_id, sha256(bytes)}
      end

    recorded =
      entries
      |> Enum.with_index(1)
      |> Enum.map(fn {{_message_id, entry}, index} ->
        fixture = if index == 1, do: name, else: "#{name}.#{index}"
        %{"data" => data} = LiveSmoke.fixture!(:gmail, fixture)
        {entry.part_id, sha256(Base.url_decode64!(data, padding: false))}
      end)

    assert live == recorded
  end

  defp manifest_entries(message) do
    Enum.filter(message.attachments, &is_binary(&1.attachment_id)) ++
      Enum.flat_map(message.messages, &manifest_entries/1)
  end

  defp original_header(%{headers: headers}, name) do
    Enum.find_value(headers, fn header -> if header.name == name, do: header.value end)
  end

  defp digest_view(%{} = map) do
    map
    |> Map.drop([:history_id, :label_ids])
    |> Map.new(fn
      {:attachment_id, id} when is_binary(id) -> {:attachment_id, :supplied}
      {:content, text} when is_binary(text) -> {:content, {:sha256, sha256(text)}}
      {:content_base64, data} when is_binary(data) -> {:content_base64, {:sha256, sha256(data)}}
      {key, value} -> {key, digest_view(value)}
    end)
  end

  defp digest_view(list) when is_list(list), do: Enum.map(list, &digest_view/1)
  defp digest_view(value), do: value

  defp sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp assert_traversal_matches_recording(access_token, path, fixture) do
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, fixture)

    assert {:ok, %Req.Response{status: 200, body: live}} =
             access_token
             |> Client.Transport.request()
             |> Req.get(url: path, params: [format: "full"])

    live_traversals = traverse_payloads(LiveSmoke.sanitize(live))
    recorded_traversals = traverse_payloads(LiveSmoke.fixture!(:gmail, fixture))

    assert live_traversals != []
    assert live_traversals == recorded_traversals
  end

  defp traverse_payloads(%{"messages" => messages}),
    do: Enum.flat_map(messages, &traverse_payloads/1)

  defp traverse_payloads(%{"payload" => payload}) do
    assert {:ok, traversal} = Traversal.traverse(payload)
    [mask_attachment_ids(traversal)]
  end

  defp mask_attachment_ids(%{} = map) do
    Map.new(map, fn
      {:attachment_id, id} when is_binary(id) -> {:attachment_id, :supplied}
      {key, value} -> {key, mask_attachment_ids(value)}
    end)
  end

  defp mask_attachment_ids(list) when is_list(list), do: Enum.map(list, &mask_attachment_ids/1)
  defp mask_attachment_ids(value), do: value

  defp page_through(input, context, lease, pages \\ []) do
    assert length(pages) < @max_pages, "pagination did not end after #{@max_pages} pages"
    assert {:ok, page} = invoke_list(input, context, lease)

    case page do
      %{next_page_token: page_token} when is_binary(page_token) ->
        page_through(Map.put(input, :page_token, page_token), context, lease, [page | pages])

      _last_page ->
        Enum.reverse([page | pages])
    end
  end

  defp invoke_list(input, context, lease) do
    Connect.invoke(Gmail.integration(), "google.gmail.messages.list", input,
      context: context,
      credential_lease: lease
    )
  end

  defp read_grant(access_token), do: grant(access_token, [@readonly_scope])

  defp grant(access_token, scopes) do
    connection =
      Connect.Connection.new!(%{
        id: "live-gmail",
        provider: :google,
        profile: :user,
        tenant_id: "live",
        owner_type: :app_user,
        owner_id: "live-user",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live",
        actor: %{id: "live-user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live-gmail",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: scopes
      })

    {context, lease}
  end
end
