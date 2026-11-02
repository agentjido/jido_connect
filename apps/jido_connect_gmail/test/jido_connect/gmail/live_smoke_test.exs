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
  # mime_traversal_test.exs. Each test records exactly one response, so the
  # recorder sanitizes its body with fresh placeholders, as LiveSmoke.sanitize/2
  # does with the live body below; the comparison therefore sees the same
  # addresses and names on both sides. Gmail issues a new attachmentId with
  # every response, so only the presence of an attachment ID is compared.

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
