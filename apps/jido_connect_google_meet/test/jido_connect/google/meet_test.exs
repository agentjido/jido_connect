defmodule Jido.Connect.Google.MeetTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @meet_readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @meet_created_scope "https://www.googleapis.com/auth/meetings.space.created"

  @meet_action_modules [
    Jido.Connect.Google.Meet.Actions.CreateSpace,
    Jido.Connect.Google.Meet.Actions.GetSpace,
    Jido.Connect.Google.Meet.Actions.ListConferenceRecords,
    Jido.Connect.Google.Meet.Actions.GetConferenceRecord
  ]

  @meet_dsl_fragments [
    Jido.Connect.Google.Meet.Actions.Spaces,
    Jido.Connect.Google.Meet.Actions.ConferenceRecords
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
             "google.meet.conference_record.get"
           ]

    assert spec.triggers == []

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
