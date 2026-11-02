defmodule Jido.Connect.Google.Meet.LiveMeetingLookupTest do
  @moduledoc """
  Live checks that lead from a calendar event's conference ID to the Meet
  conference record, its space, its recording and its transcript document.

      mix test --only live_smoke

  `GOOGLE_CALENDAR_CONFERENCE_ID` is the `conferenceId` of the prepared
  event, as the Calendar live tests check. A conference record carries no
  event ID, so the lookup filters `conferenceRecords.list` on the space's
  meeting code and on a `start_time` window, here the event's scheduled
  occurrence. The prepared space hosted two conferences on 2026-10-30: one
  started at 16:52:10 UTC, about three minutes before the scheduled start, and
  `GOOGLE_MEET_CONFERENCE_RECORD` at 17:17:57 UTC. The meeting code matches
  both; the window keeps the prepared record only. The earlier conference,
  `conferenceRecords/6EMi…` in `conference_records_window.2.json`, belongs to
  the event as well: its notes document `1FRWev…` is attached to the event,
  and the scheduled window excludes the conference. The window is the host's
  choice; a host that needs every conference of an event widens it or allows
  a tolerance around the scheduled times. Google deletes a conference record
  30 days after the conference ended.

  The Drive live tests download `GOOGLE_MEET_RECORDING_FILE_ID` and export
  `GOOGLE_MEET_NOTES_DOCUMENT_ID`; the checks here tie both IDs to the
  prepared record. In the test tenant Meet writes the transcript as a tab of
  the meeting's Gemini notes document, titled "Notizen von Gemini" in the
  organizer's locale, so `GOOGLE_MEET_NOTES_DOCUMENT_ID` names that one shared
  document. If Meet created the transcript and the notes as separate
  documents, the Drive export test would need the notes document and the
  transcript check here would no longer hold. See `docs/live_smoke_tests.md`
  for the variables and the recording mode.

  The space and recording responses are recorded, and so are the field
  projections of the prepared record and recording that leave their times
  out. The offline tests expect those times as `nil`. The conference record
  lists and the transcript have the shapes of `conference_records_window.json`
  and `transcripts.json` and are not.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Meet

  @req_options {:jido_connect_google, :google_req_options}
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"

  # A space's phone access carries the dial-in PIN of the meeting.
  @space_masked [fields: ["pin"]]

  # The scheduled occurrence of the prepared event, 17:55 to 18:40 Berlin
  # time. @scheduled_start and @scheduled_end in
  # apps/jido_connect_google_calendar/test/jido_connect/google/calendar/live_meet_association_test.exs
  # hold the same instants with the +01:00 offset and check them against the
  # event. The packages do not depend on each other; change both together.
  @scheduled_start ~U[2026-10-30 16:55:00Z]
  @scheduled_end ~U[2026-10-30 17:40:00Z]

  describe "google.meet.conference_record.list by meeting code" do
    @tag env!([
           "GOOGLE_ACCESS_TOKEN",
           "GOOGLE_CALENDAR_CONFERENCE_ID",
           "GOOGLE_MEET_CONFERENCE_RECORD"
         ])
    test "finds the prepared record by the event's conference ID, its space's meeting code", %{
      env: env
    } do
      token = env["GOOGLE_ACCESS_TOKEN"]
      conference_id = env["GOOGLE_CALENDAR_CONFERENCE_ID"]

      assert {:ok, %{conference_records: [record]} = page} =
               invoke(
                 "google.meet.conference_record.list",
                 %{filter: occurrence_filter(conference_id)},
                 token
               )

      refute Map.has_key?(page, :next_page_token)
      assert record.conference_record_name == env["GOOGLE_MEET_CONFERENCE_RECORD"]

      # Without the window the meeting code matches every conference of the
      # space. One page holds them: on 2026-11-02 a walk at page size 1
      # returned the newest record on several pages before the next one.
      assert {:ok, %{conference_records: records} = page} =
               invoke(
                 "google.meet.conference_record.list",
                 %{filter: meeting_code_filter(conference_id)},
                 token
               )

      refute Map.has_key?(page, :next_page_token)
      names = Enum.map(records, &name/1)
      assert length(names) >= 2
      assert Enum.uniq(names) == names
      assert Enum.all?(records, &(&1.space == record.space))

      assert records |> Enum.filter(&started_in_occurrence?/1) |> Enum.map(&name/1) ==
               [record.conference_record_name]

      LiveSmoke.record(@req_options, :google_meet, "space_get", @space_masked)

      assert {:ok, %{space: space}} =
               invoke("google.meet.space.get", %{space_name: record.space}, token)

      assert space.space_name == record.space
      assert space.meeting_code == conference_id
      assert space.meeting_uri == "https://meet.google.com/" <> conference_id
      refute space.space_name == "spaces/" <> conference_id

      # A field projection leaves the meeting code and URI out of the response.
      LiveSmoke.record(@req_options, :google_meet, "space_get_name_only", @space_masked)

      assert {:ok, %{space: named}} =
               invoke("google.meet.space.get", %{space_name: record.space, fields: "name"}, token)

      assert named.space_name == record.space
      assert {named.meeting_code, named.meeting_uri} == {nil, nil}
    end
  end

  describe "google.meet.conference_record.get" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
    test "a field projection leaves the prepared record's end and expire times out", %{
      env: env
    } do
      name = env["GOOGLE_MEET_CONFERENCE_RECORD"]

      LiveSmoke.record(@req_options, :google_meet, "conference_record_get_start_only")

      assert {:ok, %{conference_record: record}} =
               invoke(
                 "google.meet.conference_record.get",
                 %{conference_record_name: name, fields: "name,space,startTime"},
                 env["GOOGLE_ACCESS_TOKEN"]
               )

      assert record.conference_record_name == name
      assert "spaces/" <> _id = record.space
      assert started_in_occurrence?(record)
      assert {record.end_time, record.expire_time} == {nil, nil}
    end
  end

  describe "google.meet.recording.get and google.meet.recording.list" do
    @tag env!([
           "GOOGLE_ACCESS_TOKEN",
           "GOOGLE_MEET_CONFERENCE_RECORD",
           "GOOGLE_MEET_RECORDING",
           "GOOGLE_MEET_RECORDING_FILE_ID"
         ])
    test "read the prepared recording's state, times and Drive file", %{env: env} do
      token = env["GOOGLE_ACCESS_TOKEN"]

      LiveSmoke.record(@req_options, :google_meet, "recording_get")

      assert {:ok, %{recording: recording}} =
               invoke(
                 "google.meet.recording.get",
                 %{recording_name: env["GOOGLE_MEET_RECORDING"]},
                 token
               )

      assert recording.recording_name == env["GOOGLE_MEET_RECORDING"]
      assert recording.state == "FILE_GENERATED"
      assert recording.drive_file_id == env["GOOGLE_MEET_RECORDING_FILE_ID"]

      assert DateTime.compare(timestamp!(recording.start_time), timestamp!(recording.end_time)) ==
               :lt

      LiveSmoke.record(@req_options, :google_meet, "recordings")

      assert {:ok, %{recordings: [listed]} = page} =
               invoke(
                 "google.meet.recording.list",
                 %{conference_record_name: env["GOOGLE_MEET_CONFERENCE_RECORD"]},
                 token
               )

      refute Map.has_key?(page, :next_page_token)
      assert listed == recording
    end

    @tag env!([
           "GOOGLE_ACCESS_TOKEN",
           "GOOGLE_MEET_CONFERENCE_RECORD",
           "GOOGLE_MEET_RECORDING",
           "GOOGLE_MEET_RECORDING_FILE_ID"
         ])
    test "a field projection leaves the prepared recording's times out", %{env: env} do
      token = env["GOOGLE_ACCESS_TOKEN"]

      LiveSmoke.record(@req_options, :google_meet, "recording_get_untimed")

      assert {:ok, %{recording: recording}} =
               invoke(
                 "google.meet.recording.get",
                 %{
                   recording_name: env["GOOGLE_MEET_RECORDING"],
                   fields: "name,state,driveDestination"
                 },
                 token
               )

      assert recording.recording_name == env["GOOGLE_MEET_RECORDING"]
      assert recording.state == "FILE_GENERATED"
      assert recording.drive_file_id == env["GOOGLE_MEET_RECORDING_FILE_ID"]
      assert {recording.start_time, recording.end_time} == {nil, nil}

      LiveSmoke.record(@req_options, :google_meet, "recordings_untimed")

      assert {:ok, %{recordings: [listed]}} =
               invoke(
                 "google.meet.recording.list",
                 %{
                   conference_record_name: env["GOOGLE_MEET_CONFERENCE_RECORD"],
                   fields: "recordings(name,state,driveDestination)"
                 },
                 token
               )

      assert listed == recording
    end
  end

  describe "google.meet.transcript.get" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_TRANSCRIPT", "GOOGLE_MEET_NOTES_DOCUMENT_ID"])
    test "the prepared transcript is written to the notes document", %{env: env} do
      assert {:ok, %{transcript: transcript}} =
               invoke(
                 "google.meet.transcript.get",
                 %{transcript_name: env["GOOGLE_MEET_TRANSCRIPT"]},
                 env["GOOGLE_ACCESS_TOKEN"]
               )

      assert transcript.state == "FILE_GENERATED"
      assert transcript.document_id == env["GOOGLE_MEET_NOTES_DOCUMENT_ID"]
    end
  end

  defp meeting_code_filter(meeting_code), do: ~s(space.meeting_code = "#{meeting_code}")

  defp occurrence_filter(meeting_code) do
    meeting_code_filter(meeting_code) <>
      ~s( AND start_time >= "#{DateTime.to_iso8601(@scheduled_start)}") <>
      ~s( AND start_time <= "#{DateTime.to_iso8601(@scheduled_end)}")
  end

  defp started_in_occurrence?(record) do
    start = timestamp!(record.start_time)

    DateTime.compare(start, @scheduled_start) != :lt and
      DateTime.compare(start, @scheduled_end) != :gt
  end

  defp name(record), do: record.conference_record_name

  defp invoke(action_id, input, access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_meet",
        provider: :google,
        profile: :user,
        tenant_id: "live_meet",
        owner_type: :app_user,
        owner_id: "live_meet",
        status: :connected,
        scopes: [@readonly_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_meet",
        actor: %{id: "live_meet", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: connection.id,
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: [@readonly_scope]
      })

    Connect.invoke(Meet.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  defp timestamp!(value) do
    {:ok, timestamp, 0} = DateTime.from_iso8601(value)
    timestamp
  end
end
