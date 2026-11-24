defmodule Jido.Connect.Google.Meet.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @created_scope "https://www.googleapis.com/auth/meetings.space.created"

  defmodule FakeMeetClient do
    def create_space(%{access_type: "OPEN"}, "token") do
      {:ok,
       Meet.Space.new!(%{
         space_name: "spaces/abc-mnop-xyz",
         meeting_uri: "https://meet.google.com/abc-mnop-xyz",
         meeting_code: "abc-mnop-xyz",
         config: %{"accessType" => "OPEN"}
       })}
    end

    def list_transcript_entries(
          %{transcript_name: "conferenceRecords/abc/transcripts/def"},
          "token"
        ) do
      Meet.Client.Response.handle_transcript_entry_list_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:google_meet, "transcript_entries")}}
      )
    end

    def get_participant(%{participant_name: "conferenceRecords/abc/participants/p"}, "token") do
      Meet.Client.Response.handle_participant_response(
        {:ok, %{status: 200, body: LiveSmoke.fixture!(:google_meet, "participant_get")}}
      )
    end
  end

  @poll_triggers ["google.meet.transcript.available"]

  @workspace_events_triggers [
    "google.meet.conference.started",
    "google.meet.conference.ended",
    "google.meet.participant.joined",
    "google.meet.participant.left",
    "google.meet.recording.started",
    "google.meet.recording.ended",
    "google.meet.recording.file_generated",
    "google.meet.transcript.started",
    "google.meet.transcript.ended",
    "google.meet.transcript.file_generated"
  ]

  # The transcript reader adds entry text and the participants its entries name.
  @transcript_reads [
    "google.meet.transcript.entry.list",
    "google.meet.participant.list",
    "google.meet.participant.get"
  ]

  @metadata_reads [
    "google.meet.space.get",
    "google.meet.conference_record.list",
    "google.meet.conference_record.get",
    "google.meet.recording.list",
    "google.meet.recording.get",
    "google.meet.transcript.list",
    "google.meet.transcript.get"
  ]

  test "reader pack exposes action-first metadata reads only" do
    results =
      Catalog.search_tools("meet",
        modules: [Meet],
        packs: Meet.catalog_packs(),
        pack: :google_meet_reader
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.meet.space.get" in ids
    assert "google.meet.conference_record.list" in ids
    assert "google.meet.conference_record.get" in ids
    assert "google.meet.recording.list" in ids
    assert "google.meet.recording.get" in ids
    assert "google.meet.transcript.list" in ids
    assert "google.meet.transcript.get" in ids
    refute "google.meet.space.create" in ids
    refute "google.meet.transcript.entry.list" in ids
    refute "google.meet.participant.list" in ids
    refute "google.meet.participant.get" in ids
    refute "google.meet.conference.started" in ids

    assert Enum.sort(Meet.reader_pack().allowed_tools) == Enum.sort(@metadata_reads)

    pack = Meet.reader_pack()
    assert pack.metadata.risk == :read
    assert pack.metadata.triggers == @poll_triggers
    assert "google.meet.conference.started" in pack.metadata.future_triggers

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.meet.space.create",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_reader
             )
  end

  test "transcript reader pack adds transcript entries to the metadata reads" do
    results =
      Catalog.search_tools("meet",
        modules: [Meet],
        packs: Meet.catalog_packs(),
        pack: :google_meet_transcript_reader
      )

    ids = Enum.map(results, & &1.tool.id)

    for tool_id <- @metadata_reads do
      assert tool_id in ids
    end

    assert "google.meet.transcript.entry.list" in ids
    assert "google.meet.participant.list" in ids
    assert "google.meet.participant.get" in ids
    refute "google.meet.space.create" in ids

    assert Enum.sort(Meet.transcript_reader_pack().allowed_tools) ==
             Enum.sort(@metadata_reads ++ @transcript_reads)

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.meet.transcript.entry.list",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_transcript_reader
             )

    assert descriptor.tool.id == "google.meet.transcript.entry.list"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.meet.transcript.entry.list",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_reader
             )

    pack = Meet.transcript_reader_pack()
    assert pack.id == :google_meet_transcript_reader
    assert pack.metadata.risk == :read
    assert pack.metadata.triggers == @poll_triggers
    assert pack in Meet.catalog_packs()

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Meet,
      id_prefix: "google.meet.",
      pack_id_prefix: "google_meet_",
      module_namespace: Jido.Connect.Google.Meet
    )
  end

  test "scheduler pack adds meeting-space creation without exposing triggers" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.meet.space.create",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_scheduler
             )

    assert descriptor.tool.id == "google.meet.space.create"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.meet.conference_record.get",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_scheduler
             )

    assert descriptor.tool.id == "google.meet.conference_record.get"

    pack = Meet.scheduler_pack()
    assert pack.metadata.risk == :write
    assert pack.metadata.triggers == @poll_triggers
    assert "google.meet.transcript.file_generated" in pack.metadata.future_triggers
  end

  test "every pack names the poll trigger and keeps the Workspace Events triggers for later" do
    for pack <- Meet.catalog_packs() do
      assert pack.metadata.triggers == @poll_triggers
      assert pack.metadata.future_triggers == @workspace_events_triggers
      refute "google.meet.transcript.available" in pack.allowed_tools
    end
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease(scopes: [@created_scope])

    assert {:ok, %{space: %{space_name: "spaces/abc-mnop-xyz"}}} =
             Catalog.call_tool(
               "google.meet.space.create",
               %{access_type: "OPEN"},
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_scheduler,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.meet.space.create",
               %{access_type: "OPEN"},
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_reader,
               context: context,
               credential_lease: lease
             )
  end

  test "only the transcript reader pack calls the transcript entry list" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])
    input = %{transcript_name: "conferenceRecords/abc/transcripts/def"}

    assert {:ok, %{transcript_entries: [_entry]}} =
             Catalog.call_tool("google.meet.transcript.entry.list", input,
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_transcript_reader,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool("google.meet.transcript.entry.list", input,
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_reader,
               context: context,
               credential_lease: lease
             )
  end

  test "only the transcript reader pack resolves a transcript speaker" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])
    input = %{participant_name: "conferenceRecords/abc/participants/p"}

    assert {:ok, %{participant: %{user_type: "signed_in_user"}}} =
             Catalog.call_tool("google.meet.participant.get", input,
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_transcript_reader,
               context: context,
               credential_lease: lease
             )

    for pack <- [:google_meet_reader, :google_meet_scheduler] do
      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.call_tool("google.meet.participant.get", input,
                 modules: [Meet],
                 packs: Meet.catalog_packs(),
                 pack: pack,
                 context: context,
                 credential_lease: lease
               )
    end
  end

  defp context_and_lease(opts) do
    scopes = Keyword.get(opts, :scopes, [@readonly_scope])

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
