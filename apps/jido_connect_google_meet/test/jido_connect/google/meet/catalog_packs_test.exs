defmodule Jido.Connect.Google.Meet.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Meet

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
  end

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
    refute "google.meet.conference.started" in ids

    pack = Meet.reader_pack()
    assert pack.metadata.risk == :read
    assert pack.metadata.triggers == :later
    assert "google.meet.conference.started" in pack.metadata.future_triggers

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.meet.space.create",
               modules: [Meet],
               packs: Meet.catalog_packs(),
               pack: :google_meet_reader
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
    assert pack.metadata.triggers == :later
    assert "google.meet.transcript.file_generated" in pack.metadata.future_triggers
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
