defmodule Jido.Connect.Google.MeetTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  @meet_readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @meet_created_scope "https://www.googleapis.com/auth/meetings.space.created"

  @meet_action_modules [
    Jido.Connect.Google.Meet.Actions.CreateSpace,
    Jido.Connect.Google.Meet.Actions.GetSpace,
    Jido.Connect.Google.Meet.Actions.ListConferenceRecords,
    Jido.Connect.Google.Meet.Actions.GetConferenceRecord,
    Jido.Connect.Google.Meet.Actions.ListParticipants,
    Jido.Connect.Google.Meet.Actions.GetParticipant,
    Jido.Connect.Google.Meet.Actions.ListRecordings,
    Jido.Connect.Google.Meet.Actions.GetRecording,
    Jido.Connect.Google.Meet.Actions.ListTranscripts,
    Jido.Connect.Google.Meet.Actions.GetTranscript,
    Jido.Connect.Google.Meet.Actions.ListTranscriptEntries
  ]

  @meet_dsl_fragments [
    Jido.Connect.Google.Meet.Actions.Spaces,
    Jido.Connect.Google.Meet.Actions.ConferenceRecords,
    Jido.Connect.Google.Meet.Actions.Participants,
    Jido.Connect.Google.Meet.Actions.Recordings,
    Jido.Connect.Google.Meet.Actions.Transcripts,
    Jido.Connect.Google.Meet.Triggers.Transcripts
  ]

  defmodule FakeMeetClient do
    def create_space(
          %{
            access_type: "OPEN",
            config: %{"moderation" => "OFF"}
          },
          "token"
        ) do
      {:ok,
       Meet.Space.new!(%{
         space_name: "spaces/abc-mnop-xyz",
         meeting_uri: "https://meet.google.com/abc-mnop-xyz",
         meeting_code: "abc-mnop-xyz",
         config: %{"accessType" => "OPEN", "moderation" => "OFF"}
       })}
    end

    def get_space(%{space_name: "spaces/abc-mnop-xyz"}, "token") do
      {:ok,
       Meet.Space.new!(%{
         space_name: "spaces/abc-mnop-xyz",
         meeting_uri: "https://meet.google.com/abc-mnop-xyz",
         meeting_code: "abc-mnop-xyz"
       })}
    end

    def list_conference_records(%{page_size: 25, filter: "space.name = \"spaces/abc\""}, "token") do
      {:ok,
       %{
         conference_records: [
           Meet.ConferenceRecord.new!(%{
             conference_record_name: "conferenceRecords/abc",
             space: "spaces/abc",
             start_time: "2026-05-14T18:00:00Z"
           })
         ],
         next_page_token: "next"
       }}
    end

    def get_conference_record(%{conference_record_name: "conferenceRecords/abc"}, "token") do
      {:ok,
       Meet.ConferenceRecord.new!(%{
         conference_record_name: "conferenceRecords/abc",
         space: "spaces/abc",
         start_time: "2026-05-14T18:00:00Z"
       })}
    end

    def list_participants(
          %{conference_record_name: "conferenceRecords/abc", page_size: 10},
          "token"
        ) do
      Meet.Client.Response.handle_participant_list_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:google_meet, "participants")}}
      )
    end

    def get_participant(%{participant_name: "conferenceRecords/abc/participants/p"}, "token") do
      Meet.Client.Response.handle_participant_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:google_meet, "participant_get")}}
      )
    end

    def list_recordings(
          %{conference_record_name: "conferenceRecords/abc", page_size: 10},
          "token"
        ) do
      {:ok,
       %{
         recordings: [
           Meet.Recording.new!(%{
             recording_name: "conferenceRecords/abc/recordings/def",
             state: "FILE_GENERATED",
             drive_file_id: "drive-file-1",
             export_uri: "https://drive.google.com/file/d/drive-file-1/view"
           })
         ],
         next_page_token: "recordings-next"
       }}
    end

    def get_recording(%{recording_name: "conferenceRecords/abc/recordings/def"}, "token") do
      {:ok,
       Meet.Recording.new!(%{
         recording_name: "conferenceRecords/abc/recordings/def",
         state: "FILE_GENERATED",
         drive_file_id: "drive-file-1"
       })}
    end

    def list_transcripts(
          %{conference_record_name: "conferenceRecords/abc", page_size: 10},
          "token"
        ) do
      {:ok,
       %{
         transcripts: [
           Meet.Transcript.new!(%{
             transcript_name: "conferenceRecords/abc/transcripts/ghi",
             state: "FILE_GENERATED",
             document_id: "doc-1",
             export_uri: "https://docs.google.com/document/d/doc-1/view"
           })
         ],
         next_page_token: "transcripts-next"
       }}
    end

    def get_transcript(%{transcript_name: "conferenceRecords/abc/transcripts/ghi"}, "token") do
      {:ok,
       Meet.Transcript.new!(%{
         transcript_name: "conferenceRecords/abc/transcripts/ghi",
         state: "FILE_GENERATED",
         document_id: "doc-1"
       })}
    end

    def list_transcript_entries(
          %{transcript_name: "conferenceRecords/abc/transcripts/def", page_size: 10},
          "token"
        ) do
      Meet.Client.Response.handle_transcript_entry_list_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:google_meet, "transcript_entries")}}
      )
    end
  end

  test "declares Google Meet provider metadata" do
    spec = Meet.integration()

    assert spec.id == :google_meet
    assert spec.package == :jido_connect_google_meet
    assert spec.name == "Google Meet"
    assert spec.category == :collaboration
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :meetings, :collaboration]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.meet.space.create",
             "google.meet.space.get",
             "google.meet.conference_record.list",
             "google.meet.conference_record.get",
             "google.meet.participant.list",
             "google.meet.participant.get",
             "google.meet.recording.list",
             "google.meet.recording.get",
             "google.meet.transcript.list",
             "google.meet.transcript.get",
             "google.meet.transcript.entry.list"
           ]

    assert [%{id: "google.meet.transcript.available"}] = spec.triggers

    assert {:ok,
            %{
              kind: :poll,
              interval_ms: 300_000,
              checkpoint: :end_time_watermark,
              dedupe: %{key: [:transcript_name]},
              scope_resolver: Jido.Connect.Google.Meet.ScopeResolver,
              handler: Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptPoller
            } = trigger} = Connect.trigger(spec, "google.meet.transcript.available")

    assert Enum.map(trigger.signal, & &1.name) == [
             :transcript_name,
             :conference_record_name,
             :document_id,
             :state,
             :start_time,
             :end_time,
             :export_uri
           ]

    refute Enum.any?(spec.triggers, &(&1.id == "google.meet.transcript.file_generated"))

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Meet,
      id_prefix: "google.meet.",
      pack_id_prefix: "google_meet_",
      module_namespace: Jido.Connect.Google.Meet
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @meet_readonly_scope in profile.optional_scopes
    assert @meet_created_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Meet,
      otp_app: :jido_connect_google_meet,
      action_modules: @meet_action_modules,
      sensor_specs: [
        %{
          module: Jido.Connect.Google.Meet.Sensors.TranscriptAvailable,
          name: "google_meet_transcript_available",
          trigger_id: "google.meet.transcript.available",
          signal_type: "google.meet.transcript.available"
        }
      ],
      plugin_module: Jido.Connect.Google.Meet.Plugin,
      plugin_name: "google_meet"
    )

    ConnectorContracts.assert_plugin_tool_availability(Meet)
  end

  test "loads Meet Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@meet_dsl_fragments)
  end

  test "invokes create space through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_created_scope])

    assert {:ok,
            %{
              space: %{
                space_name: "spaces/abc-mnop-xyz",
                meeting_uri: "https://meet.google.com/abc-mnop-xyz",
                meeting_code: "abc-mnop-xyz"
              }
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.space.create",
               %{access_type: "OPEN", config: %{"moderation" => "OFF"}},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get space through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              space: %{
                space_name: "spaces/abc-mnop-xyz",
                meeting_code: "abc-mnop-xyz"
              }
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.space.get",
               %{space_name: "spaces/abc-mnop-xyz"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list conference records through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              conference_records: [
                %{
                  conference_record_name: "conferenceRecords/abc",
                  space: "spaces/abc"
                }
              ],
              next_page_token: "next"
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.conference_record.list",
               %{filter: "space.name = \"spaces/abc\""},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get conference record through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              conference_record: %{
                conference_record_name: "conferenceRecords/abc",
                space: "spaces/abc"
              }
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.conference_record.get",
               %{conference_record_name: "conferenceRecords/abc"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list participants through injected client and lease" do
    recorded = LiveSmoke.fixture!(:google_meet, "participants")
    [recorded_participant] = recorded["participants"]

    for scope <- [@meet_readonly_scope, @meet_created_scope] do
      {context, lease} = context_and_lease(scopes: [scope])

      assert {:ok, %{participants: [participant], next_page_token: next_page_token}} =
               Connect.invoke(
                 Meet.integration(),
                 "google.meet.participant.list",
                 %{conference_record_name: " conferenceRecords/abc "},
                 context: context,
                 credential_lease: lease
               )

      refute is_struct(participant)
      assert next_page_token == recorded["nextPageToken"]
      assert participant.participant_name == recorded_participant["name"]
      assert participant.user_type == "signed_in_user"
      assert participant.user == recorded_participant["signedinUser"]["user"]
      assert participant.display_name == recorded_participant["signedinUser"]["displayName"]
    end
  end

  test "invokes get participant through injected client and lease" do
    recorded = LiveSmoke.fixture!(:google_meet, "participant_get")

    for scope <- [@meet_readonly_scope, @meet_created_scope] do
      {context, lease} = context_and_lease(scopes: [scope])

      assert {:ok, %{participant: participant}} =
               Connect.invoke(
                 Meet.integration(),
                 "google.meet.participant.get",
                 %{participant_name: " conferenceRecords/abc/participants/p "},
                 context: context,
                 credential_lease: lease
               )

      refute is_struct(participant)

      assert %{
               participant_name: participant_name,
               user_type: "signed_in_user",
               user: user,
               display_name: display_name,
               signed_in_user: signed_in_user,
               earliest_start_time: earliest_start_time,
               latest_end_time: latest_end_time
             } = participant

      assert {participant_name, user, display_name, signed_in_user} ==
               {recorded["name"], recorded["signedinUser"]["user"],
                recorded["signedinUser"]["displayName"], recorded["signedinUser"]}

      assert {earliest_start_time, latest_end_time} ==
               {recorded["earliestStartTime"], recorded["latestEndTime"]}
    end
  end

  test "rejects participant reads without a Meet scope" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    for {action_id, input} <- [
          {"google.meet.participant.list", %{conference_record_name: "conferenceRecords/abc"}},
          {"google.meet.participant.get",
           %{participant_name: "conferenceRecords/abc/participants/p"}}
        ] do
      assert {:error,
              %Connect.Error.AuthError{
                reason: :missing_scopes,
                missing_scopes: [@meet_readonly_scope]
              }} =
               Connect.invoke(Meet.integration(), action_id, input,
                 context: context,
                 credential_lease: lease
               )
    end
  end

  test "rejects participant reads with a blank resource name" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    for {action_id, field} <- [
          {"google.meet.participant.list", :conference_record_name},
          {"google.meet.participant.get", :participant_name}
        ],
        blank <- ["", "   "] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :invalid_conference_record_request,
                details: %{field: ^field}
              }} =
               Connect.invoke(Meet.integration(), action_id, %{field => blank},
                 context: context,
                 credential_lease: lease
               )
    end
  end

  test "invokes list recordings through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              recordings: [
                %{
                  recording_name: "conferenceRecords/abc/recordings/def",
                  drive_file_id: "drive-file-1"
                }
              ],
              next_page_token: "recordings-next"
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.recording.list",
               %{conference_record_name: "conferenceRecords/abc"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get recording through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              recording: %{
                recording_name: "conferenceRecords/abc/recordings/def",
                state: "FILE_GENERATED"
              }
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.recording.get",
               %{recording_name: "conferenceRecords/abc/recordings/def"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list transcripts through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              transcripts: [
                %{
                  transcript_name: "conferenceRecords/abc/transcripts/ghi",
                  document_id: "doc-1"
                }
              ],
              next_page_token: "transcripts-next"
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.transcript.list",
               %{conference_record_name: "conferenceRecords/abc"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get transcript through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    assert {:ok,
            %{
              transcript: %{
                transcript_name: "conferenceRecords/abc/transcripts/ghi",
                state: "FILE_GENERATED"
              }
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.transcript.get",
               %{transcript_name: "conferenceRecords/abc/transcripts/ghi"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list transcript entries through injected client and lease" do
    recorded = LiveSmoke.fixture!(:google_meet, "transcript_entries")
    [recorded_entry] = recorded["transcriptEntries"]

    for scope <- [@meet_readonly_scope, @meet_created_scope] do
      {context, lease} = context_and_lease(scopes: [scope])

      assert {:ok, %{transcript_entries: [entry], next_page_token: next_page_token}} =
               Connect.invoke(
                 Meet.integration(),
                 "google.meet.transcript.entry.list",
                 %{transcript_name: "conferenceRecords/abc/transcripts/def"},
                 context: context,
                 credential_lease: lease
               )

      refute is_struct(entry)
      assert next_page_token == recorded["nextPageToken"]

      assert %{
               entry_name: entry_name,
               participant: participant,
               text: text,
               language_code: language_code,
               start_time: start_time,
               end_time: end_time
             } = entry

      assert {entry_name, participant, text} ==
               {recorded_entry["name"], recorded_entry["participant"], recorded_entry["text"]}

      assert {language_code, start_time, end_time} ==
               {recorded_entry["languageCode"], recorded_entry["startTime"],
                recorded_entry["endTime"]}
    end
  end

  test "rejects list transcript entries without a Meet scope" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@meet_readonly_scope]
            }} =
             Connect.invoke(
               Meet.integration(),
               "google.meet.transcript.entry.list",
               %{transcript_name: "conferenceRecords/abc/transcripts/def"},
               context: context,
               credential_lease: lease
             )
  end

  test "rejects list transcript entries with a blank transcript name" do
    {context, lease} = context_and_lease(scopes: [@meet_readonly_scope])

    for transcript_name <- ["", "   "] do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :invalid_artifact_request,
                details: %{field: :transcript_name}
              }} =
               Connect.invoke(
                 Meet.integration(),
                 "google.meet.transcript.entry.list",
                 %{transcript_name: transcript_name},
                 context: context,
                 credential_lease: lease
               )
    end
  end

  defp context_and_lease(opts) do
    scopes = Keyword.get(opts, :scopes, [@meet_readonly_scope])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_meet_client: FakeMeetClient},
        scopes: scopes
      })

    {context, lease}
  end
end
