defmodule Jido.Connect.Google.Meet.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.

  The transcript entry check needs `GOOGLE_MEET_TRANSCRIPT` to hold between two
  and 1,000 entries. It lists all of them at 100 per page as the reference,
  then walks at most the first 30 entries one per page; a longer transcript is
  compared on those 30 only. At about 1.5 seconds per request the check stays
  well within its three-minute timeout.

  The transcript poll checks need the conference records prepared on
  2026-10-30: `GOOGLE_MEET_CONFERENCE_RECORD` and one earlier record in the
  same space, both ending between 16:00 and 18:00 UTC with one generated
  transcript each. The poll starts from a checkpoint whose watermark lies
  before them. A fresh meeting between two polls is a separate check. The
  window check records the fixtures of the offline poll tests and fails while
  a conference that ended after the prepared window is still listed; Google
  deletes a conference record 30 days after the conference ended.

  The checks that read the prepared records or transcript carry
  `LiveMeet.prepared!/1`. Once Google answers that this data is gone, they
  are skipped with a reason instead of failing; see "Prepared Meet data" in
  `docs/live_smoke_tests.md`. The window check and the transcript list check
  expect the earlier record as well and list it as
  `:earlier_conference_record`. The two checks without prepared data keep
  running.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.Meet.Client
  alias Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptCheckpoint
  alias Jido.Connect.Google.Meet.TestSupport.LiveMeet

  require LiveMeet

  # Google returns at most 100 transcript entries per page.
  @reference_page_size 100
  @reference_page_limit 10
  @single_entry_page_limit 30

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"

  # The prepared conference records ended inside this window.
  @prepared_window_start ~U[2026-10-30 16:00:00Z]
  @prepared_window_end ~U[2026-10-30 18:00:00Z]
  @record_page_limit 5

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "lists one page of conference records", %{env: env} do
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "conference_records"
    )

    assert {:ok, result} =
             Client.list_conference_records(%{page_size: 1}, env["GOOGLE_ACCESS_TOKEN"])

    assert is_map(result)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag timeout: :timer.minutes(3)
  test "pages through transcript entries in meeting order", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    transcript = env["GOOGLE_MEET_TRANSCRIPT"]

    # All entries at the largest page size are the reference for the walk below.
    {reference_pages, reference_walk} =
      entry_pages(transcript, token, @reference_page_size, @reference_page_limit)

    assert reference_walk == :complete,
           "the transcript has more than #{@reference_page_size * @reference_page_limit} entries"

    reference = Enum.flat_map(reference_pages, & &1.transcript_entries)

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "transcript_entries",
      fields: ["text"]
    )

    {pages, walk} = entry_pages(transcript, token, 1, @single_entry_page_limit)
    entries = Enum.flat_map(pages, & &1.transcript_entries)

    assert length(pages) >= 2
    assert Enum.all?(pages, &(length(&1.transcript_entries) <= 1))

    # A complete walk matches the whole reference; a truncated one its start.
    expected =
      case walk do
        :complete ->
          reference

        :truncated ->
          assert length(reference) > length(entries)
          Enum.take(reference, length(entries))
      end

    assert Enum.map(entries, &attribution/1) == Enum.map(expected, &attribution/1)
    assert length(entries) >= 2

    names = Enum.map(entries, & &1.entry_name)
    assert Enum.uniq(names) == names
    assert Enum.all?(names, &String.starts_with?(&1, transcript <> "/entries/"))

    participant_prefix = env["GOOGLE_MEET_CONFERENCE_RECORD"] <> "/participants/"
    assert Enum.all?(entries, &String.starts_with?(&1.participant, participant_prefix))

    starts = Enum.map(entries, &timestamp!(&1.start_time))
    assert starts == Enum.sort(starts, DateTime)

    for entry <- entries do
      assert DateTime.compare(timestamp!(entry.start_time), timestamp!(entry.end_time)) != :gt
      assert is_binary(entry.language_code)
      assert is_binary(entry.text) and entry.text != ""
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])
  test "rejects the entries of a missing transcript", %{env: env} do
    missing =
      env["GOOGLE_MEET_CONFERENCE_RECORD"] <>
        "/transcripts/00000000-0000-0000-0000-000000000000"

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "transcript_entries_not_found"
    )

    assert {:error, %ProviderError{provider: :google, reason: :http_error, status: 404}} =
             Client.list_transcript_entries(
               %{transcript_name: missing, page_size: 1},
               env["GOOGLE_ACCESS_TOKEN"]
             )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", :earlier_conference_record])
  test "pages through the conference records of an end time window", %{env: env} do
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "conference_records_window"
    )

    filter = TranscriptCheckpoint.window_filter(@prepared_window_start)
    pages = record_pages(filter, env["GOOGLE_ACCESS_TOKEN"])
    records = Enum.flat_map(pages, & &1.conference_records)
    names = Enum.map(records, & &1.conference_record_name)

    # The offline poll tests serve this recording as two pages: the prepared
    # record, then the earlier one. A conference that ended after the prepared
    # window, such as a fresh meeting, adds a page the recording must not get.
    assert Enum.all?(pages, &(length(&1.conference_records) == 1))
    assert [prepared, earlier] = names
    assert prepared == env["GOOGLE_MEET_CONFERENCE_RECORD"]

    # The poller tolerates a repeated record, but this filter should not cause one.
    assert earlier != prepared

    for record <- records do
      end_time = timestamp!(record.end_time)
      assert DateTime.compare(end_time, @prepared_window_start) != :lt

      assert DateTime.compare(end_time, @prepared_window_end) != :gt,
             "a conference ended after the prepared window; the offline tests expect the prepared records only"
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "lists no conference records for a watermark at the current time", %{env: env} do
    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "conference_records_window_empty"
    )

    # No conference ends in the future, as after a poll that found nothing new.
    filter = TranscriptCheckpoint.window_filter(DateTime.utc_now())

    assert {:ok, %{conference_records: []} = page} =
             Client.list_conference_records(
               %{filter: filter, page_size: 100},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    refute Map.has_key?(page, :next_page_token)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!([
         "GOOGLE_MEET_CONFERENCE_RECORD",
         "GOOGLE_MEET_TRANSCRIPT",
         :earlier_conference_record
       ])
  test "lists the generated transcript of each prepared conference record", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    prepared = env["GOOGLE_MEET_CONFERENCE_RECORD"]

    prepared_window =
      ~s(end_time>="#{DateTime.to_iso8601(@prepared_window_start)}" AND ) <>
        ~s(end_time<="#{DateTime.to_iso8601(@prepared_window_end)}")

    assert {:ok, %{conference_records: records}} =
             Client.list_conference_records(%{filter: prepared_window, page_size: 100}, token)

    assert [earlier] = Enum.map(records, & &1.conference_record_name) -- [prepared]

    LiveSmoke.record({:jido_connect_google, :google_req_options}, :google_meet, "transcripts")

    assert {:ok, %{transcripts: [transcript]} = page} =
             Client.list_transcripts(%{conference_record_name: prepared, page_size: 100}, token)

    refute Map.has_key?(page, :next_page_token)
    assert transcript.transcript_name == env["GOOGLE_MEET_TRANSCRIPT"]
    assert_generated(transcript)

    LiveSmoke.record(
      {:jido_connect_google, :google_req_options},
      :google_meet,
      "transcripts_earlier_record"
    )

    assert {:ok, %{transcripts: [transcript]}} =
             Client.list_transcripts(%{conference_record_name: earlier, page_size: 100}, token)

    assert String.starts_with?(transcript.transcript_name, earlier <> "/transcripts/")
    assert_generated(transcript)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag timeout: :timer.minutes(2)
  test "polls the prepared transcript once and nothing on the repeat", %{env: env} do
    checkpoint =
      JSON.encode!(%{
        "version" => 1,
        "watermark" => DateTime.to_iso8601(@prepared_window_start),
        "settled" => [],
        "pending" => []
      })

    assert {:ok, %{signals: signals, checkpoint: next_checkpoint}} =
             poll_transcripts(env["GOOGLE_ACCESS_TOKEN"], checkpoint)

    assert [signal] = Enum.filter(signals, &(&1.transcript_name == env["GOOGLE_MEET_TRANSCRIPT"]))
    assert signal.conference_record_name == env["GOOGLE_MEET_CONFERENCE_RECORD"]
    assert %{state: "FILE_GENERATED", document_id: document_id} = signal
    assert is_binary(document_id) and document_id != ""

    transcript_names = Enum.map(signals, & &1.transcript_name)
    assert Enum.uniq(transcript_names) == transcript_names

    assert {:ok, %{signals: [], checkpoint: ^next_checkpoint}} =
             poll_transcripts(env["GOOGLE_ACCESS_TOKEN"], next_checkpoint)
  end

  # Follows next_page_token for at most `limit` pages and tells whether the
  # last page ended the listing.
  defp entry_pages(transcript, token, page_size, limit, page_token \\ nil, pages \\ [])

  defp entry_pages(_transcript, _token, _page_size, 0, _page_token, pages),
    do: {Enum.reverse(pages), :truncated}

  defp entry_pages(transcript, token, page_size, limit, page_token, pages) do
    params = %{transcript_name: transcript, page_size: page_size, page_token: page_token}
    assert {:ok, page} = Client.list_transcript_entries(params, token)
    pages = [page | pages]

    case page do
      %{next_page_token: next} when is_binary(next) ->
        entry_pages(transcript, token, page_size, limit - 1, next, pages)

      _last ->
        {Enum.reverse(pages), :complete}
    end
  end

  defp attribution(entry), do: {entry.entry_name, entry.participant, entry.start_time}

  # Follows next_page_token one record per page and fails past the page limit.
  defp record_pages(filter, token, page_token \\ nil, pages \\ []) do
    assert length(pages) < @record_page_limit, "the window has too many conference records"
    params = %{filter: filter, page_size: 1, page_token: page_token}
    assert {:ok, page} = Client.list_conference_records(params, token)
    pages = [page | pages]

    case page do
      %{next_page_token: next} when is_binary(next) -> record_pages(filter, token, next, pages)
      _last -> Enum.reverse(pages)
    end
  end

  defp assert_generated(transcript) do
    assert %{state: "FILE_GENERATED", document_id: document_id} = transcript
    assert is_binary(document_id) and document_id != ""
  end

  defp poll_transcripts(token, checkpoint) do
    connection =
      Connect.Connection.new!(%{
        id: "live_conn",
        provider: :google,
        profile: :user,
        tenant_id: "live_tenant",
        owner_type: :app_user,
        owner_id: "live_user",
        status: :connected,
        scopes: [@readonly_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_tenant",
        actor: %{id: "live_user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live_conn",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: token},
        scopes: [@readonly_scope]
      })

    Connect.poll(Meet.integration(), "google.meet.transcript.available", %{},
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp timestamp!(value) do
    {:ok, timestamp, 0} = DateTime.from_iso8601(value)
    timestamp
  end
end
