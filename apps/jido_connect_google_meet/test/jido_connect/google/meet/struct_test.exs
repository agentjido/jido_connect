defmodule Jido.Connect.Google.Meet.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.{
    ConferenceRecord,
    Participant,
    Recording,
    Space,
    Transcript,
    TranscriptEntry
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  test "space struct validates with Zoi" do
    space =
      ConnectorContracts.assert_struct_defaults(Space, %{space_name: "spaces/abc-mnop-xyz"},
        config: %{},
        phone_access: [],
        gateway_sip_access: [],
        metadata: %{}
      )

    assert space.space_name == "spaces/abc-mnop-xyz"
    assert {:error, _error} = Space.new(%{})
  end

  test "conference record struct validates with Zoi" do
    record =
      ConnectorContracts.assert_struct_defaults(
        ConferenceRecord,
        %{conference_record_name: "conferenceRecords/abc-123"},
        metadata: %{}
      )

    assert record.conference_record_name == "conferenceRecords/abc-123"
    assert {:error, _error} = ConferenceRecord.new(%{})
  end

  test "participant struct validates with Zoi" do
    participant =
      ConnectorContracts.assert_struct_defaults(
        Participant,
        %{
          participant_name: "conferenceRecords/abc-123/participants/user-123",
          user_type: "signed_in_user",
          user: "users/123",
          display_name: "Ada Lovelace",
          signed_in_user: %{"user" => "users/123", "displayName" => "Ada Lovelace"}
        },
        metadata: %{}
      )

    assert participant.display_name == "Ada Lovelace"
    assert {:error, _error} = Participant.new(%{})
  end

  test "recording struct validates with Zoi without content bytes" do
    recording =
      ConnectorContracts.assert_struct_defaults(
        Recording,
        %{
          recording_name: "conferenceRecords/abc-123/recordings/recording-123",
          state: "FILE_GENERATED",
          drive_file_id: "drive-file-123",
          export_uri: "https://drive.google.com/file/d/drive-file-123/view",
          drive_destination: %{
            "file" => "drive-file-123",
            "exportUri" => "https://drive.google.com/file/d/drive-file-123/view"
          }
        },
        metadata: %{}
      )

    assert recording.drive_file_id == "drive-file-123"
    assert {:error, _error} = Recording.new(%{})
  end

  test "transcript struct validates with Zoi without transcript content" do
    transcript =
      ConnectorContracts.assert_struct_defaults(
        Transcript,
        %{
          transcript_name: "conferenceRecords/abc-123/transcripts/transcript-123",
          state: "FILE_GENERATED",
          document_id: "doc-123",
          export_uri: "https://docs.google.com/document/d/doc-123/view",
          docs_destination: %{
            "document" => "doc-123",
            "exportUri" => "https://docs.google.com/document/d/doc-123/view"
          }
        },
        metadata: %{}
      )

    assert transcript.document_id == "doc-123"
    assert {:error, _error} = Transcript.new(%{})
  end

  test "transcript entry struct keeps Unicode text and attribution unchanged" do
    [recorded] = LiveSmoke.fixture!(:google_meet, "transcript_entries")["transcriptEntries"]
    text = "Grüße aus Köln 👋\nZweite Zeile: 東京, café\r\n— Ende"

    entry =
      ConnectorContracts.assert_struct_defaults(
        TranscriptEntry,
        %{
          entry_name: recorded["name"],
          participant: recorded["participant"],
          text: text,
          language_code: recorded["languageCode"],
          start_time: recorded["startTime"],
          end_time: recorded["endTime"]
        },
        metadata: %{}
      )

    assert entry.entry_name == recorded["name"]
    assert entry.participant == recorded["participant"]
    assert entry.text == text
    assert entry.language_code == recorded["languageCode"]
    assert entry.start_time == recorded["startTime"]
    assert entry.end_time == recorded["endTime"]

    bare = TranscriptEntry.new!(%{entry_name: recorded["name"]})
    assert {bare.participant, bare.text, bare.language_code} == {nil, nil, nil}
    assert {bare.start_time, bare.end_time} == {nil, nil}

    assert {:error, _error} = TranscriptEntry.new(%{})
    assert {:error, _error} = TranscriptEntry.new(%{entry_name: recorded["name"], text: 42})
  end
end
