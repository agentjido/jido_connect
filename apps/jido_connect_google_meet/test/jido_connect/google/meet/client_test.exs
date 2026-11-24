defmodule Jido.Connect.Google.Meet.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error.ProviderError

  alias Jido.Connect.Google.Meet.{
    Client,
    ConferenceRecord,
    Participant,
    Recording,
    Space,
    Transcript,
    TranscriptEntry
  }

  alias Jido.Connect.TestSupport.LiveSmoke

  @transcript_name "conferenceRecords/abc/transcripts/def"

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
    # Recorded through the meeting code with this field projection: Google
    # accepts `spaces/<meeting code>` and names the space by its own ID.
    %{"meetingCode" => meeting_code} =
      recorded = LiveSmoke.fixture!(:google_meet, "space_get_by_meeting_code")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/spaces/#{meeting_code}"
      assert conn.query_params["fields"] == "name,meetingUri,meetingCode"

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %Space{} = space} =
             Client.get_space(
               %{space_name: "spaces/#{meeting_code}", fields: "name,meetingUri,meetingCode"},
               "token"
             )

    assert space.space_name == recorded["name"]
    assert space.meeting_code == meeting_code
    assert space.meeting_uri == recorded["meetingUri"]
    refute space.space_name == "spaces/#{meeting_code}"
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

  test "forwards a meeting code filter with a start time window to the conference record list" do
    filter =
      ~s(space.meeting_code = "abc-mnop-xyz") <>
        ~s( AND start_time >= "2026-05-14T00:00:00Z") <>
        ~s( AND start_time <= "2026-05-15T00:00:00Z")

    # The client forwards the filter without evaluating it, so the response
    # need not match it. This page of one record and a next page token was
    # recorded at page size 1 with the transcript poller's `end_time>=`
    # filter, and its record started on 2026-10-30.
    recorded = LiveSmoke.fixture!(:google_meet, "conference_records_window")
    [recorded_record] = recorded["conferenceRecords"]

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords"

      assert conn.query_params == %{
               "filter" => filter,
               "pageSize" => "1",
               "pageToken" => "previous-page"
             }

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %{conference_records: [%ConferenceRecord{} = record], next_page_token: next}} =
             Client.list_conference_records(
               %{filter: filter, page_size: 1, page_token: "previous-page"},
               "token"
             )

    assert next == recorded["nextPageToken"]
    assert record.conference_record_name == recorded_record["name"]
    assert record.space == recorded_record["space"]
    assert record.start_time == recorded_record["startTime"]
    assert record.end_time == recorded_record["endTime"]
    assert record.expire_time == recorded_record["expireTime"]
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
    # Derived from recordings_untimed, the live list under the projection
    # `recordings(name,state,driveDestination)`. The prepared conference has
    # one recording, so Google sends no nextPageToken for it: the unprojected
    # list in `recordings.json` has none, and adding `nextPageToken` to the
    # projection cannot add one. The token below is the one field added to
    # the recorded page, so the test can check that the client returns it.
    recorded = LiveSmoke.fixture!(:google_meet, "recordings_untimed")
    [recorded_recording] = recorded["recordings"]
    page = Map.put(recorded, "nextPageToken", "derived-next-page")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["pageToken"] == "older"

      assert conn.query_params["fields"] ==
               "recordings(name,state,driveDestination),nextPageToken"

      Req.Test.json(conn, page)
    end)

    assert {:ok, %{recordings: [%Recording{} = recording], next_page_token: "derived-next-page"}} =
             Client.list_recordings(
               %{
                 conference_record_name: "conferenceRecords/abc",
                 page_size: 10,
                 page_token: "older",
                 fields: "recordings(name,state,driveDestination),nextPageToken"
               },
               "token"
             )

    assert recording.recording_name == recorded_recording["name"]
    assert recording.drive_file_id == recorded_recording["driveDestination"]["file"]
  end

  test "gets Meet recording metadata" do
    # Recorded under the same field projection.
    recorded = LiveSmoke.fixture!(:google_meet, "recording_get_untimed")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings/def"
      assert conn.query_params["fields"] == "name,state,driveDestination"

      Req.Test.json(conn, recorded)
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

  test "lists Meet recordings with their start and end times" do
    recorded = LiveSmoke.fixture!(:google_meet, "recordings")

    assert [%{"startTime" => _start, "endTime" => _end} = recorded_recording] =
             recorded["recordings"]

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings"
      assert conn.query_params == %{}

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %{recordings: [%Recording{} = recording]} = page} =
             Client.list_recordings(%{conference_record_name: "conferenceRecords/abc"}, "token")

    refute Map.has_key?(page, :next_page_token)
    assert_recording(recording, recorded_recording)
  end

  test "gets a Meet recording with its start and end times" do
    recorded = LiveSmoke.fixture!(:google_meet, "recording_get")
    assert %{"startTime" => _start, "endTime" => _end} = recorded

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/recordings/def"
      assert conn.query_params == %{}

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %Recording{} = recording} =
             Client.get_recording(
               %{recording_name: "conferenceRecords/abc/recordings/def"},
               "token"
             )

    assert_recording(recording, recorded)
  end

  test "leaves Meet recording start and end times nil when the response has none" do
    # Recorded with field projections that leave both times out.
    get_fields = "name,state,driveDestination"
    list_fields = "recordings(#{get_fields})"
    recorded_get = LiveSmoke.fixture!(:google_meet, "recording_get_untimed")
    recorded_list = LiveSmoke.fixture!(:google_meet, "recordings_untimed")
    [listed_recorded] = recorded_list["recordings"]

    for recorded <- [recorded_get, listed_recorded] do
      assert Enum.sort(Map.keys(recorded)) == ["driveDestination", "name", "state"]
    end

    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.request_path, conn.query_params} do
        {"/v2/conferenceRecords/abc/recordings", %{"fields" => ^list_fields}} ->
          Req.Test.json(conn, recorded_list)

        {"/v2/conferenceRecords/abc/recordings/def", %{"fields" => ^get_fields}} ->
          Req.Test.json(conn, recorded_get)
      end
    end)

    assert {:ok, %{recordings: [listed]}} =
             Client.list_recordings(
               %{conference_record_name: "conferenceRecords/abc", fields: list_fields},
               "token"
             )

    assert {:ok, fetched} =
             Client.get_recording(
               %{recording_name: "conferenceRecords/abc/recordings/def", fields: get_fields},
               "token"
             )

    for {recording, recorded} <- [{listed, listed_recorded}, {fetched, recorded_get}] do
      assert {recording.start_time, recording.end_time} == {nil, nil}
      assert_recording(recording, recorded)
    end
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

  test "lists Meet transcript entries with the next page token" do
    recorded = LiveSmoke.fixture!(:google_meet, "transcript_entries")
    [recorded_entry] = recorded["transcriptEntries"]

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/def/entries"
      assert conn.query_params["pageSize"] == "1"
      assert conn.query_params["pageToken"] == "older"

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %{transcript_entries: [%TranscriptEntry{} = entry], next_page_token: next}} =
             Client.list_transcript_entries(
               %{transcript_name: @transcript_name, page_size: 1, page_token: "older"},
               "token"
             )

    assert next == recorded["nextPageToken"]
    assert entry.entry_name == recorded_entry["name"]
    assert entry.participant == recorded_entry["participant"]
    assert entry.text == recorded_entry["text"]
    assert entry.language_code == recorded_entry["languageCode"]
    assert entry.start_time == recorded_entry["startTime"]
    assert entry.end_time == recorded_entry["endTime"]
  end

  test "lists no Meet transcript entries when the body has none" do
    recorded = LiveSmoke.fixture!(:google_meet, "transcript_entries.2")
    refute Map.has_key?(recorded, "nextPageToken")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/def/entries"

      Req.Test.json(conn, Map.delete(recorded, "transcriptEntries"))
    end)

    assert {:ok, %{transcript_entries: []} = result} =
             Client.list_transcript_entries(%{transcript_name: @transcript_name}, "token")

    refute Map.has_key?(result, :next_page_token)
  end

  test "percent-encodes reserved characters in the transcript name segments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/d%3Fe%23f/entries"
      assert conn.query_params == %{"pageSize" => "1"}

      Req.Test.json(conn, LiveSmoke.fixture!(:google_meet, "transcript_entries.2"))
    end)

    assert {:ok, %{transcript_entries: [%TranscriptEntry{}]}} =
             Client.list_transcript_entries(
               %{transcript_name: "conferenceRecords/abc/transcripts/d?e#f", page_size: 1},
               "token"
             )
  end

  test "returns provider errors for malformed transcript entry list responses" do
    recorded = LiveSmoke.fixture!(:google_meet, "transcript_entries")
    [recorded_entry] = recorded["transcriptEntries"]

    malformed_entries = [
      Map.delete(recorded_entry, "name"),
      Map.put(recorded_entry, "text", [recorded_entry["text"]])
    ]

    for malformed_entry <- malformed_entries do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/def/entries"

        Req.Test.json(conn, Map.put(recorded, "transcriptEntries", [malformed_entry]))
      end)

      assert {:error,
              %Jido.Connect.Error.ProviderError{
                provider: :google,
                reason: :invalid_response
              }} = Client.list_transcript_entries(%{transcript_name: @transcript_name}, "token")
    end

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, Map.put(recorded, "transcriptEntries", recorded_entry))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.list_transcript_entries(%{transcript_name: @transcript_name}, "token")

    Req.Test.stub(__MODULE__, &Req.Test.json(&1, recorded["transcriptEntries"]))

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response, status: nil}} =
             Client.list_transcript_entries(%{transcript_name: @transcript_name}, "token")
  end

  test "returns a provider error for a missing transcript instead of empty entries" do
    not_found = LiveSmoke.fixture!(:google_meet, "transcript_entries_not_found")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/v2/conferenceRecords/abc/transcripts/def/entries"

      conn
      |> Plug.Conn.put_status(not_found["error"]["code"])
      |> Req.Test.json(not_found)
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :http_error,
              status: 404,
              details: %{message: "Transcript not found"}
            }} = Client.list_transcript_entries(%{transcript_name: @transcript_name}, "token")
  end

  describe "participants" do
    @record_name "conferenceRecords/abc"

    test "lists the participants of a conference record page by page" do
      first = LiveSmoke.fixture!(:google_meet, "participants")
      last = LiveSmoke.fixture!(:google_meet, "participants.2")
      token = first["nextPageToken"]

      Req.Test.expect(__MODULE__, 2, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/conferenceRecords/abc/participants"
        assert conn.query_params["pageSize"] == "1"
        assert conn.query_params["fields"] == "participants,nextPageToken"

        case conn.query_params["pageToken"] do
          nil -> Req.Test.json(conn, first)
          ^token -> Req.Test.json(conn, last)
        end
      end)

      params = %{
        conference_record_name: @record_name,
        page_size: 1,
        fields: "participants,nextPageToken"
      }

      assert {:ok, %{participants: [%Participant{} = one], next_page_token: ^token}} =
               Client.list_participants(params, "token")

      assert {:ok, %{participants: [%Participant{} = two]} = page} =
               Client.list_participants(Map.put(params, :page_token, token), "token")

      refute Map.has_key?(page, :next_page_token)

      for {participant, [recorded]} <- [
            {one, first["participants"]},
            {two, last["participants"]}
          ] do
        assert_signed_in_participant(participant, recorded)
      end
    end

    test "lists no participants when the body has none" do
      recorded = LiveSmoke.fixture!(:google_meet, "participants.2")

      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v2/conferenceRecords/abc/participants"
        Req.Test.json(conn, Map.delete(recorded, "participants"))
      end)

      assert {:ok, %{participants: []} = result} =
               Client.list_participants(%{conference_record_name: @record_name}, "token")

      refute Map.has_key?(result, :next_page_token)
    end

    test "gets the participant that a transcript entry names as its speaker" do
      recorded = LiveSmoke.fixture!(:google_meet, "participant_get")
      [entry] = LiveSmoke.fixture!(:google_meet, "transcript_entries")["transcriptEntries"]
      speaker = entry["participant"]
      assert speaker == recorded["name"]
      [_record, segment] = String.split(speaker, "/participants/")

      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/conferenceRecords/abc/participants/#{segment}"
        assert conn.query_params == %{"fields" => "name,signedinUser"}
        Req.Test.json(conn, recorded)
      end)

      assert {:ok, %Participant{} = participant} =
               Client.get_participant(
                 %{
                   participant_name: "#{@record_name}/participants/#{segment}",
                   fields: "name,signedinUser"
                 },
                 "token"
               )

      assert_signed_in_participant(participant, recorded)
    end

    test "keeps a participant without user kind from a field projection" do
      # Recorded with the field projection "name".
      recorded = LiveSmoke.fixture!(:google_meet, "participant_get_name_only")
      assert Map.keys(recorded) == ["name"]

      Req.Test.stub(__MODULE__, &Req.Test.json(&1, recorded))

      assert {:ok, %Participant{} = participant} =
               Client.get_participant(
                 %{participant_name: recorded["name"], fields: "name"},
                 "token"
               )

      assert participant.participant_name == recorded["name"]

      assert {participant.user_type, participant.user, participant.display_name} ==
               {nil, nil, nil}
    end

    test "percent-encodes reserved characters in the participant name segments" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case conn.request_path do
          "/v2/conferenceRecords/a%3Fb%23c/participants" ->
            Req.Test.json(conn, LiveSmoke.fixture!(:google_meet, "participants.2"))

          "/v2/conferenceRecords/abc/participants/d%3Fe%23f" ->
            Req.Test.json(conn, LiveSmoke.fixture!(:google_meet, "participant_get"))
        end
      end)

      assert {:ok, %{participants: [%Participant{}]}} =
               Client.list_participants(
                 %{conference_record_name: "conferenceRecords/a?b#c"},
                 "token"
               )

      assert {:ok, %Participant{}} =
               Client.get_participant(
                 %{participant_name: "conferenceRecords/abc/participants/d?e#f"},
                 "token"
               )
    end

    test "returns provider errors for malformed participant responses" do
      [recorded] = LiveSmoke.fixture!(:google_meet, "participants")["participants"]
      page = LiveSmoke.fixture!(:google_meet, "participants")

      malformed = [
        Map.delete(recorded, "name"),
        Map.put(recorded, "name", 42),
        Map.put(recorded, "signedinUser", "users/1"),
        Map.put(recorded, "anonymousUser", %{"displayName" => "Person 9"})
      ]

      for participant <- malformed do
        Req.Test.stub(__MODULE__, fn conn ->
          case conn.request_path do
            "/v2/conferenceRecords/abc/participants" ->
              Req.Test.json(conn, Map.put(page, "participants", [participant]))

            "/v2/conferenceRecords/abc/participants/p" ->
              Req.Test.json(conn, participant)
          end
        end)

        assert {:error, %ProviderError{provider: :google, reason: :invalid_response}} =
                 Client.list_participants(%{conference_record_name: @record_name}, "token")

        assert {:error, %ProviderError{provider: :google, reason: :invalid_response}} =
                 Client.get_participant(
                   %{participant_name: "#{@record_name}/participants/p"},
                   "token"
                 )
      end

      Req.Test.stub(__MODULE__, &Req.Test.json(&1, Map.put(page, "participants", recorded)))

      assert {:error, %ProviderError{reason: :invalid_response}} =
               Client.list_participants(%{conference_record_name: @record_name}, "token")

      Req.Test.stub(__MODULE__, &Req.Test.json(&1, page["participants"]))

      assert {:error, %ProviderError{reason: :invalid_response, status: nil}} =
               Client.list_participants(%{conference_record_name: @record_name}, "token")

      assert {:error, %ProviderError{reason: :invalid_response, status: nil}} =
               Client.get_participant(
                 %{participant_name: "#{@record_name}/participants/p"},
                 "token"
               )
    end

    test "returns a provider error when a transcript entry name stands in for its speaker" do
      # Recorded for the entry name of the prepared transcript's first entry.
      entry = LiveSmoke.fixture!(:google_meet, "participant_get_transcript_entry")

      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v2/" <> entry["name"]
        Req.Test.json(conn, entry)
      end)

      assert {:error, %ProviderError{provider: :google, reason: :invalid_response, status: nil}} =
               Client.get_participant(%{participant_name: entry["name"]}, "token")
    end

    test "returns a provider error for a missing participant" do
      not_found = LiveSmoke.fixture!(:google_meet, "participant_not_found")
      respond_with_recorded_error(not_found)

      assert {:error,
              %ProviderError{
                provider: :google,
                reason: :http_error,
                status: 404,
                details: %{message: "Participant not found"}
              }} =
               Client.get_participant(
                 %{participant_name: "#{@record_name}/participants/p"},
                 "token"
               )
    end

    test "returns a provider error for the participants of an invalid conference record" do
      invalid = LiveSmoke.fixture!(:google_meet, "participants_invalid_record")
      respond_with_recorded_error(invalid)

      assert {:error,
              %ProviderError{
                provider: :google,
                reason: :http_error,
                status: 400,
                details: %{message: "Invalid conference id"}
              }} = Client.list_participants(%{conference_record_name: @record_name}, "token")
    end
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

  defp assert_signed_in_participant(participant, recorded) do
    signed_in = recorded["signedinUser"]

    assert participant.participant_name == recorded["name"]
    assert participant.user_type == "signed_in_user"
    assert participant.user == signed_in["user"]
    assert participant.display_name == signed_in["displayName"]
    assert participant.signed_in_user == signed_in
    assert {participant.anonymous_user, participant.phone_user} == {nil, nil}
    assert participant.earliest_start_time == recorded["earliestStartTime"]
    assert participant.latest_end_time == recorded["latestEndTime"]
  end

  defp respond_with_recorded_error(body) do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(body["error"]["code"])
      |> Req.Test.json(body)
    end)
  end

  defp assert_recording(recording, recorded) do
    assert recording.recording_name == recorded["name"]
    assert recording.state == recorded["state"]
    assert recording.drive_file_id == recorded["driveDestination"]["file"]
    assert recording.start_time == recorded["startTime"]
    assert recording.end_time == recorded["endTime"]
  end
end
