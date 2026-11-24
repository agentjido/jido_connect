defmodule Jido.Connect.Google.Meet.LivePreparedDataTest do
  @moduledoc """
  Live checks of the answers on which `LiveMeet.prepared!/1` decides whether
  the prepared Meet data still exists.

      mix test --only live_smoke

  Google deletes a conference record, and the transcript entries under it,
  30 days after the conference ends. Its answer for a deleted record cannot be
  seen before then, so the first check asks about a well-formed conference
  record ID that names no conference the test user can see. Google answers
  that request, and the transcript entries under it, with 403
  `PERMISSION_DENIED`, no ErrorInfo reason and a message saying the resource
  might not exist. That check needs no living data and keeps its meaning after
  the prepared data is gone.

  The other checks read the prepared data and carry `LiveMeet.prepared!/1`. A
  token without a Meet scope also gets a 403 `PERMISSION_DENIED`, which names
  its ErrorInfo reason and must not count as expired data. The probes that
  `prepared!/1` sends read the prepared record and one transcript entry
  without its text.

  The 403 answers are recorded as `conference_record_unknown`,
  `transcript_entries_unknown_record` and
  `conference_record_scope_insufficient` for the offline tests of `LiveMeet`.
  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Meet.TestSupport.LiveMeet

  require LiveMeet

  @req_options {:jido_connect_google, :google_req_options}
  @error_info "type.googleapis.com/google.rpc.ErrorInfo"

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  test "a conference record that does not exist answers 403 for itself and its entries", %{
    env: env
  } do
    token = env["GOOGLE_ACCESS_TOKEN"]
    unknown = unknown_record(env["GOOGLE_MEET_CONFERENCE_RECORD"])
    transcript_id = env["GOOGLE_MEET_TRANSCRIPT"] |> String.split("/") |> List.last()

    LiveSmoke.record(@req_options, :google_meet, "conference_record_unknown")
    record = LiveMeet.probe("GOOGLE_MEET_CONFERENCE_RECORD", unknown, token)

    assert_not_visible(record)
    assert LiveMeet.expired?(record)

    LiveSmoke.record(@req_options, :google_meet, "transcript_entries_unknown_record")
    transcript = unknown <> "/transcripts/" <> transcript_id
    entries = LiveMeet.probe("GOOGLE_MEET_TRANSCRIPT", transcript, token)

    assert_not_visible(entries)
    assert LiveMeet.expired?(entries)
  end

  @tag env!(["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])
  test "a token without a Meet scope answers 403 with its ErrorInfo reason", %{env: env} do
    LiveSmoke.record(@req_options, :google_meet, "conference_record_scope_insufficient")

    result =
      LiveMeet.probe(
        "GOOGLE_MEET_CONFERENCE_RECORD",
        env["GOOGLE_MEET_CONFERENCE_RECORD"],
        env["GOOGLE_GMAIL_METADATA_ACCESS_TOKEN"]
      )

    assert {:ok, %{status: 403, body: %{"error" => error}}} = result
    assert error["status"] == "PERMISSION_DENIED"
    assert [%{"reason" => "ACCESS_TOKEN_SCOPE_INSUFFICIENT"}] = error_infos(error)
    refute LiveMeet.expired?(result)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  test "the probes read the prepared record and one entry without its text", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    record = env["GOOGLE_MEET_CONFERENCE_RECORD"]
    transcript = env["GOOGLE_MEET_TRANSCRIPT"]

    assert {:ok, %{status: 200, body: %{"name" => ^record} = body}} =
             LiveMeet.probe("GOOGLE_MEET_CONFERENCE_RECORD", record, token)

    assert Map.keys(body) == ["name"]

    assert {:ok, %{status: 200, body: %{"transcriptEntries" => [entry]}}} =
             LiveMeet.probe("GOOGLE_MEET_TRANSCRIPT", transcript, token)

    assert Map.keys(entry) == ["name"]
    assert String.starts_with?(entry["name"], transcript <> "/entries/")
  end

  # Google answers an ID it cannot parse with 400 INVALID_ARGUMENT "Invalid
  # conference id", so a made-up ID would check the wrong answer. Flipping the
  # lowest bit of the first decoded byte of the prepared ID keeps the ID
  # well-formed, while it names no conference the test user can see.
  defp unknown_record("conferenceRecords/" <> id) do
    <<first, rest::binary>> = Base.url_decode64!(id, padding: false)
    flipped = <<Bitwise.bxor(first, 1), rest::binary>>

    "conferenceRecords/" <> Base.url_encode64(flipped, padding: false)
  end

  defp assert_not_visible(result) do
    assert {:ok, %{status: 403, body: %{"error" => error}}} = result
    assert error["status"] == "PERMISSION_DENIED"
    assert error["message"] =~ "might not exist"
    assert error_infos(error) == []
  end

  defp error_infos(error) do
    error
    |> Map.get("details", [])
    |> Enum.filter(&(&1["@type"] == @error_info))
  end
end
