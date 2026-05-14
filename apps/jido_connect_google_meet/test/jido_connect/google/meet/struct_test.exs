defmodule Jido.Connect.Google.Meet.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.{
    ConferenceRecord,
    Participant,
    Recording,
    Space,
    Transcript
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

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
end
