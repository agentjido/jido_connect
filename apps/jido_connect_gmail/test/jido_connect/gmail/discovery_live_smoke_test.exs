defmodule Jido.Connect.Gmail.DiscoveryLiveSmokeTest do
  @moduledoc """
  Live checks of inbox and archive discovery and of metadata reads under a
  `gmail.metadata` grant, against the prepared messages of the Google
  Workspace test account.

      mix test --only live_smoke

  A query search through `google.gmail.messages.list` pages through its
  matches one message at a time and must find the prepared inbox and archived
  messages; the same query with the `INBOX` label must return the inbox ones
  only. Google must reject a query search that the client sends with a token
  limited to `gmail.metadata`. Under that token, a metadata read of one
  message of the archive pair and of its thread that asks for the `Subject`
  header must return that header only; these reads record
  `message_metadata_subject` and `thread_metadata_subject`.

  The tests read `GOOGLE_ACCESS_TOKEN`, `GOOGLE_GMAIL_METADATA_ACCESS_TOKEN`,
  `GOOGLE_GMAIL_QUERY` and `GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID`; see
  `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Client
  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  @max_pages 20
  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"

  # Prepared data of the test account: GOOGLE_GMAIL_QUERY matches exactly these
  # messages. The seed script restores them, possibly under new IDs.
  @query_matches 5
  @query_inbox_matches 3
  @query_archived_matches 2

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_QUERY"])
  test "a query search pages through inbox and archived messages", %{env: env} do
    {context, lease} = LiveGmail.read_grant(env["GOOGLE_ACCESS_TOKEN"])
    query = env["GOOGLE_GMAIL_QUERY"]

    LiveGmail.record("messages_list_query")
    pages = page_through(%{query: query, page_size: 1}, context, lease)

    assert Enum.all?(pages, &(length(&1.messages) <= 1))

    match_ids = pages |> Enum.flat_map(& &1.messages) |> Enum.map(& &1.message_id)
    assert length(match_ids) == @query_matches
    assert length(match_ids) == length(Enum.uniq(match_ids))

    LiveGmail.record("messages_list_query_inbox")

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
    LiveGmail.record("messages_list_query_metadata_scope")

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

  # Metadata reads of one message of the archive pair and of its thread,
  # asking for one header, under the scope the metadata actions need. The
  # offline client tests send the same requests. On 2026-11-06 Gmail answered
  # them without a snippet, and each payload held only that header and an
  # empty partId, no mimeType and no body.
  @tag env!(["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN", "GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"])
  test "message.get and thread.get return only the requested Subject header under the metadata-only grant",
       %{env: env} do
    {context, lease} =
      LiveGmail.grant(env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"], [@metadata_scope])

    message_id = env["GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID"]
    input = %{message_id: message_id, metadata_headers: ["Subject"]}

    LiveGmail.record("message_metadata_subject")

    assert {:ok, %{message: %{message_id: ^message_id, thread_id: thread_id} = message}} =
             Connect.invoke(Gmail.integration(), "google.gmail.message.get", input,
               context: context,
               credential_lease: lease
             )

    assert [%{name: "Subject"}] = message.headers
    refute Map.has_key?(message.payload_summary, :body_size)

    LiveGmail.record("thread_metadata_subject")

    assert {:ok, %{thread: %{thread_id: ^thread_id, messages: [_first, _second] = messages}}} =
             Connect.invoke(
               Gmail.integration(),
               "google.gmail.thread.get",
               %{thread_id: thread_id, metadata_headers: ["Subject"]},
               context: context,
               credential_lease: lease
             )

    assert message_id in Enum.map(messages, & &1.message_id)

    for listed <- messages do
      assert [%{name: "Subject"}] = listed.headers
      refute Map.has_key?(listed.payload_summary, :body_size)
    end
  end

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
end
