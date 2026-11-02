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

  defp read_grant(access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live-gmail",
        provider: :google,
        profile: :user,
        tenant_id: "live",
        owner_type: :app_user,
        owner_id: "live-user",
        status: :connected,
        scopes: [@readonly_scope]
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
        scopes: [@readonly_scope]
      })

    {context, lease}
  end
end
