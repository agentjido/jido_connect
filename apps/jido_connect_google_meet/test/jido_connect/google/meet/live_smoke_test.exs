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
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Google.Meet.Client

  # Google returns at most 100 transcript entries per page.
  @reference_page_size 100
  @reference_page_limit 10
  @single_entry_page_limit 30

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

  defp timestamp!(value) do
    {:ok, timestamp, 0} = DateTime.from_iso8601(value)
    timestamp
  end
end
