defmodule Jido.Connect.Google.Meet.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.{
    ConferenceRecord,
    Normalizer,
    Participant,
    Recording,
    Space,
    Transcript,
    TranscriptEntry
  }

  alias Jido.Connect.TestSupport.LiveSmoke

  @unicode_text "Grüße aus Köln 👋\nZweite Zeile: 東京, café\r\n— Ende"

  test "normalizes Meet space payloads" do
    assert {:ok,
            %Space{
              space_name: "spaces/abc-mnop-xyz",
              meeting_uri: "https://meet.google.com/abc-mnop-xyz",
              meeting_code: "abc-mnop-xyz",
              phone_access: [%{"regionCode" => "US"}],
              gateway_sip_access: [%{"uri" => "sip:123@example.com"}]
            }} =
             Normalizer.space(%{
               "name" => "spaces/abc-mnop-xyz",
               "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
               "meetingCode" => "abc-mnop-xyz",
               "config" => %{"accessType" => "OPEN"},
               "activeConference" => %{"conferenceRecord" => "conferenceRecords/abc"},
               "phoneAccess" => [%{"regionCode" => "US"}],
               "gatewaySipAccess" => [%{"uri" => "sip:123@example.com"}]
             })
  end

  test "keeps the name of a Meet space without meeting code and URI" do
    recorded = LiveSmoke.fixture!(:google_meet, "space_get_name_only")

    assert {:ok, %Space{} = space} = Normalizer.space(recorded)

    assert space.space_name == recorded["name"]
    assert {space.meeting_code, space.meeting_uri} == {nil, nil}
  end

  test "rejects malformed Meet space payloads" do
    assert {:error, _error} = Normalizer.space(%{"meetingCode" => "missing-name"})
    assert {:error, :invalid_space_payload} = Normalizer.space(nil)
  end

  test "normalizes Meet conference record payloads" do
    assert {:ok,
            %ConferenceRecord{
              conference_record_name: "conferenceRecords/abc",
              space: "spaces/abc",
              start_time: "2026-05-14T18:00:00Z",
              end_time: "2026-05-14T19:00:00Z",
              expire_time: "2026-06-13T19:00:00Z"
            }} =
             Normalizer.conference_record(%{
               "name" => "conferenceRecords/abc",
               "space" => "spaces/abc",
               "startTime" => "2026-05-14T18:00:00Z",
               "endTime" => "2026-05-14T19:00:00Z",
               "expireTime" => "2026-06-13T19:00:00Z"
             })
  end

  test "keeps the start time of a Meet conference record without end and expire times" do
    # Recorded with the field projection "name,space,startTime".
    recorded = LiveSmoke.fixture!(:google_meet, "conference_record_get_start_only")
    assert Enum.sort(Map.keys(recorded)) == ["name", "space", "startTime"]

    assert {:ok, %ConferenceRecord{} = record} = Normalizer.conference_record(recorded)

    assert record.conference_record_name == recorded["name"]
    assert record.space == recorded["space"]
    assert record.start_time == recorded["startTime"]
    assert {record.end_time, record.expire_time} == {nil, nil}
  end

  test "rejects malformed Meet conference record payloads" do
    assert {:error, _error} = Normalizer.conference_record(%{"space" => "spaces/abc"})
    assert {:error, :invalid_conference_record_payload} = Normalizer.conference_record(nil)
  end

  test "normalizes Meet recording metadata payloads" do
    assert {:ok,
            %Recording{
              recording_name: "conferenceRecords/abc/recordings/def",
              state: "FILE_GENERATED",
              drive_destination: %{
                "file" => "drive-file-1",
                "exportUri" => "https://drive.google.com/file/d/drive-file-1/view"
              },
              drive_file_id: "drive-file-1",
              export_uri: "https://drive.google.com/file/d/drive-file-1/view"
            }} =
             Normalizer.recording(%{
               "name" => "conferenceRecords/abc/recordings/def",
               "state" => "FILE_GENERATED",
               "driveDestination" => %{
                 "file" => "drive-file-1",
                 "exportUri" => "https://drive.google.com/file/d/drive-file-1/view"
               }
             })
  end

  test "rejects malformed Meet recording payloads" do
    assert {:error, _error} = Normalizer.recording(%{"state" => "FILE_GENERATED"})
    assert {:error, :invalid_recording_payload} = Normalizer.recording(nil)
  end

  test "normalizes Meet transcript metadata payloads" do
    assert {:ok,
            %Transcript{
              transcript_name: "conferenceRecords/abc/transcripts/ghi",
              state: "FILE_GENERATED",
              docs_destination: %{
                "document" => "doc-1",
                "exportUri" => "https://docs.google.com/document/d/doc-1/view"
              },
              document_id: "doc-1",
              export_uri: "https://docs.google.com/document/d/doc-1/view"
            }} =
             Normalizer.transcript(%{
               "name" => "conferenceRecords/abc/transcripts/ghi",
               "state" => "FILE_GENERATED",
               "docsDestination" => %{
                 "document" => "doc-1",
                 "exportUri" => "https://docs.google.com/document/d/doc-1/view"
               }
             })
  end

  test "rejects malformed Meet transcript payloads" do
    assert {:error, _error} = Normalizer.transcript(%{"state" => "FILE_GENERATED"})
    assert {:error, :invalid_transcript_payload} = Normalizer.transcript(nil)
  end

  test "normalizes recorded Meet transcript entries with Unicode text unchanged" do
    recorded_entry = recorded_entry() |> Map.put("text", @unicode_text)

    assert {:ok, %TranscriptEntry{} = entry} = Normalizer.transcript_entry(recorded_entry)

    assert entry.entry_name == recorded_entry["name"]
    assert entry.participant == recorded_entry["participant"]
    assert entry.text == @unicode_text
    assert entry.language_code == recorded_entry["languageCode"]
    assert entry.start_time == recorded_entry["startTime"]
    assert entry.end_time == recorded_entry["endTime"]
    assert entry.metadata == %{}
  end

  test "keeps absent optional transcript entry fields absent" do
    recorded_entry =
      Map.drop(recorded_entry(), ["participant", "text", "languageCode", "startTime", "endTime"])

    assert {:ok, %TranscriptEntry{} = entry} = Normalizer.transcript_entry(recorded_entry)

    assert entry.entry_name == recorded_entry["name"]
    assert entry.participant == nil
    assert entry.text == nil
    assert entry.language_code == nil
    assert entry.start_time == nil
    assert entry.end_time == nil
  end

  test "rejects malformed Meet transcript entry payloads" do
    assert {:error, _error} = Normalizer.transcript_entry(Map.delete(recorded_entry(), "name"))

    assert {:error, _error} =
             Normalizer.transcript_entry(Map.put(recorded_entry(), "text", %{"value" => "x"}))

    assert {:error, :invalid_transcript_entry_payload} = Normalizer.transcript_entry(nil)
  end

  test "normalizes a recorded signed-in Meet participant" do
    recorded = LiveSmoke.fixture!(:google_meet, "participant_get")
    signed_in = recorded["signedinUser"]

    assert {:ok, %Participant{} = participant} = Normalizer.participant(recorded)

    assert participant.participant_name == recorded["name"]
    assert participant.user_type == "signed_in_user"
    assert participant.user == signed_in["user"]
    assert participant.display_name == signed_in["displayName"]
    assert participant.signed_in_user == signed_in
    assert {participant.anonymous_user, participant.phone_user} == {nil, nil}
    assert participant.earliest_start_time == recorded["earliestStartTime"]
    assert participant.latest_end_time == recorded["latestEndTime"]
    assert participant.metadata == %{}
  end

  test "names anonymous and phone participants by their user kind" do
    # Derived from the recorded participant: the prepared meeting had only
    # signed-in participants, so the other two user kinds replace its own.
    recorded = LiveSmoke.fixture!(:google_meet, "participant_get")

    for {key, user_type, field} <- [
          {"anonymousUser", "anonymous_user", :anonymous_user},
          {"phoneUser", "phone_user", :phone_user}
        ] do
      kind = %{"displayName" => "Person 2"}
      payload = recorded |> Map.delete("signedinUser") |> Map.put(key, kind)

      assert {:ok, %Participant{} = participant} = Normalizer.participant(payload)

      assert participant.participant_name == recorded["name"]
      assert participant.user_type == user_type
      assert participant.display_name == "Person 2"
      assert participant.user == nil
      assert Map.fetch!(participant, field) == kind
      assert participant.signed_in_user == nil
    end
  end

  test "keeps a Meet participant without user kind as returned for a field projection" do
    # Recorded with the field projection "name".
    recorded = LiveSmoke.fixture!(:google_meet, "participant_get_name_only")

    assert {:ok, %Participant{} = participant} = Normalizer.participant(recorded)

    assert participant.participant_name == recorded["name"]
    assert {participant.user_type, participant.user, participant.display_name} == {nil, nil, nil}

    assert {participant.signed_in_user, participant.anonymous_user, participant.phone_user} ==
             {nil, nil, nil}

    assert {participant.earliest_start_time, participant.latest_end_time} == {nil, nil}
  end

  test "rejects another Meet resource in place of a participant" do
    for fixture <- ["participant_get_transcript_entry", "conference_record_get_start_only"] do
      assert {:error, :not_a_participant} =
               Normalizer.participant(LiveSmoke.fixture!(:google_meet, fixture))
    end
  end

  test "rejects malformed Meet participant payloads" do
    recorded = LiveSmoke.fixture!(:google_meet, "participant_get")

    for payload <- [
          Map.delete(recorded, "name"),
          Map.put(recorded, "name", ["conferenceRecords/abc/participants/1"]),
          Map.put(recorded, "signedinUser", "users/1"),
          put_in(recorded, ["signedinUser", "displayName"], %{"text" => "Person 1"}),
          put_in(recorded, ["signedinUser", "user"], 42)
        ] do
      assert {:error, _error} = Normalizer.participant(payload)
    end

    assert {:error, :ambiguous_participant_user} =
             Normalizer.participant(
               Map.put(recorded, "phoneUser", %{"displayName" => "Person 2"})
             )

    assert {:error, :invalid_participant_payload} = Normalizer.participant(nil)
  end

  defp recorded_entry do
    [entry] = LiveSmoke.fixture!(:google_meet, "transcript_entries")["transcriptEntries"]
    entry
  end
end
