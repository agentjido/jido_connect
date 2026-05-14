defmodule Jido.Connect.Google.Meet.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Meet.{Client, ConferenceRecord, Recording, Space, Transcript}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_meet,
      :google_meet_api_base_url,
      "https://meet.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_meet, :google_meet_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "creates a Meet space" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/spaces"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "config" => %{
                 "accessType" => "OPEN",
                 "moderation" => "OFF"
               }
             }

      Req.Test.json(conn, %{
        "name" => "spaces/abc-mnop-xyz",
        "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
        "meetingCode" => "abc-mnop-xyz",
        "config" => %{"accessType" => "OPEN", "moderation" => "OFF"}
      })
    end)

    assert {:ok, %Space{} = space} =
             Client.create_space(%{access_type: "OPEN", moderation: "OFF"}, "token")

    assert space.space_name == "spaces/abc-mnop-xyz"
    assert space.meeting_code == "abc-mnop-xyz"
  end

  test "gets a Meet space" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/spaces/abc-mnop-xyz"
      assert conn.query_params["fields"] == "name,meetingUri,meetingCode"

      Req.Test.json(conn, %{
        "name" => "spaces/abc-mnop-xyz",
        "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
        "meetingCode" => "abc-mnop-xyz"
      })
    end)

    assert {:ok, %Space{} = space} =
             Client.get_space(
               %{space_name: "spaces/abc-mnop-xyz", fields: "name,meetingUri,meetingCode"},
               "token"
             )

    assert space.meeting_uri == "https://meet.google.com/abc-mnop-xyz"
  end

  test "lists Meet conference records" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords"
      assert conn.query_params["pageSize"] == "25"
      assert conn.query_params["pageToken"] == "older"
      assert conn.query_params["filter"] == ~s(space.name = "spaces/abc")
      assert conn.query_params["fields"] == "conferenceRecords(name,space),nextPageToken"

      Req.Test.json(conn, %{
        "conferenceRecords" => [
          %{
            "name" => "conferenceRecords/abc",
            "space" => "spaces/abc",
            "startTime" => "2026-05-14T18:00:00Z"
          }
        ],
        "nextPageToken" => "next"
      })
    end)

    assert {:ok, %{conference_records: [%ConferenceRecord{} = record], next_page_token: "next"}} =
             Client.list_conference_records(
               %{
                 page_size: 25,
                 page_token: "older",
                 filter: ~s(space.name = "spaces/abc"),
                 fields: "conferenceRecords(name,space),nextPageToken"
               },
               "token"
             )

    assert record.conference_record_name == "conferenceRecords/abc"
    assert record.space == "spaces/abc"
  end

  test "gets a Meet conference record" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc"
      assert conn.query_params["fields"] == "name,space,startTime"

      Req.Test.json(conn, %{
        "name" => "conferenceRecords/abc",
        "space" => "spaces/abc",
        "startTime" => "2026-05-14T18:00:00Z"
      })
    end)

    assert {:ok, %ConferenceRecord{} = record} =
             Client.get_conference_record(
               %{conference_record_name: "conferenceRecords/abc", fields: "name,space,startTime"},
               "token"
             )

    assert record.start_time == "2026-05-14T18:00:00Z"
  end

  test "lists Meet recording metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["pageToken"] == "older"

      assert conn.query_params["fields"] ==
               "recordings(name,state,driveDestination),nextPageToken"

      Req.Test.json(conn, %{
        "recordings" => [
          %{
            "name" => "conferenceRecords/abc/recordings/def",
            "state" => "FILE_GENERATED",
            "driveDestination" => %{
              "file" => "drive-file-1",
              "exportUri" => "https://drive.google.com/file/d/drive-file-1/view"
            }
          }
        ],
        "nextPageToken" => "next"
      })
    end)

    assert {:ok, %{recordings: [%Recording{} = recording], next_page_token: "next"}} =
             Client.list_recordings(
               %{
                 conference_record_name: "conferenceRecords/abc",
                 page_size: 10,
                 page_token: "older",
                 fields: "recordings(name,state,driveDestination),nextPageToken"
               },
               "token"
             )

    assert recording.recording_name == "conferenceRecords/abc/recordings/def"
    assert recording.drive_file_id == "drive-file-1"
  end

  test "gets Meet recording metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings/def"
      assert conn.query_params["fields"] == "name,state,driveDestination"

      Req.Test.json(conn, %{
        "name" => "conferenceRecords/abc/recordings/def",
        "state" => "FILE_GENERATED",
        "driveDestination" => %{"file" => "drive-file-1"}
      })
    end)

    assert {:ok, %Recording{} = recording} =
             Client.get_recording(
               %{
                 recording_name: "conferenceRecords/abc/recordings/def",
                 fields: "name,state,driveDestination"
               },
               "token"
             )

    assert recording.state == "FILE_GENERATED"
  end

  test "lists Meet transcript metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts"
      assert conn.query_params["pageSize"] == "10"

      assert conn.query_params["fields"] ==
               "transcripts(name,state,docsDestination),nextPageToken"

      Req.Test.json(conn, %{
        "transcripts" => [
          %{
            "name" => "conferenceRecords/abc/transcripts/ghi",
            "state" => "FILE_GENERATED",
            "docsDestination" => %{
              "document" => "doc-1",
              "exportUri" => "https://docs.google.com/document/d/doc-1/view"
            }
          }
        ],
        "nextPageToken" => "next"
      })
    end)

    assert {:ok, %{transcripts: [%Transcript{} = transcript], next_page_token: "next"}} =
             Client.list_transcripts(
               %{
                 conference_record_name: "conferenceRecords/abc",
                 page_size: 10,
                 fields: "transcripts(name,state,docsDestination),nextPageToken"
               },
               "token"
             )

    assert transcript.transcript_name == "conferenceRecords/abc/transcripts/ghi"
    assert transcript.document_id == "doc-1"
  end

  test "gets Meet transcript metadata" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/ghi"
      assert conn.query_params["fields"] == "name,state,docsDestination"

      Req.Test.json(conn, %{
        "name" => "conferenceRecords/abc/transcripts/ghi",
        "state" => "FILE_GENERATED",
        "docsDestination" => %{"document" => "doc-1"}
      })
    end)

    assert {:ok, %Transcript{} = transcript} =
             Client.get_transcript(
               %{
                 transcript_name: "conferenceRecords/abc/transcripts/ghi",
                 fields: "name,state,docsDestination"
               },
               "token"
             )

    assert transcript.state == "FILE_GENERATED"
  end

  test "returns provider errors for malformed space responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/spaces/missing-name"

      Req.Test.json(conn, %{"meetingCode" => "missing-name"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_space(%{space_name: "spaces/missing-name"}, "token")
  end

  test "returns provider errors for malformed conference record list responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords"

      Req.Test.json(conn, %{"conferenceRecords" => [%{"space" => "spaces/abc"}]})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_conference_records(%{}, "token")
  end

  test "returns provider errors for malformed recording responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings/def"

      Req.Test.json(conn, %{"state" => "FILE_GENERATED"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.get_recording(
               %{recording_name: "conferenceRecords/abc/recordings/def"},
               "token"
             )
  end

  test "returns provider errors for malformed transcript responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/ghi"

      Req.Test.json(conn, %{"state" => "FILE_GENERATED"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.get_transcript(
               %{transcript_name: "conferenceRecords/abc/transcripts/ghi"},
               "token"
             )
  end
end
