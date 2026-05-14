defmodule Jido.Connect.Google.AnalyticsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Analytics
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @analytics_readonly_scope "https://www.googleapis.com/auth/analytics.readonly"
  @analytics_action_modules [
    Jido.Connect.Google.Analytics.Actions.GetMetadata
  ]
  @analytics_dsl_fragments [
    Jido.Connect.Google.Analytics.Actions.Metadata
  ]

  defmodule FakeAnalyticsClient do
    def get_metadata(%{property: "properties/1234"}, "token") do
      {:ok,
       %{
         metadata_name: "properties/1234/metadata",
         dimensions: [
           Analytics.Dimension.new!(%{
             name: "country",
             display_name: "Country",
             category: "Geography"
           })
         ],
         metrics: [
           Analytics.Metric.new!(%{
             name: "activeUsers",
             display_name: "Active users",
             type: "TYPE_INTEGER"
           })
         ],
         comparisons: []
       }}
    end
  end

  test "declares Google Analytics provider metadata" do
    spec = Analytics.integration()

    assert spec.id == :google_analytics
    assert spec.package == :jido_connect_google_analytics
    assert spec.name == "Google Analytics"
    assert spec.category == :marketing
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :analytics, :reporting]
    assert Enum.map(spec.actions, & &1.id) == ["google.analytics.metadata.get"]
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @analytics_readonly_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Analytics,
      otp_app: :jido_connect_google_analytics,
      action_modules: @analytics_action_modules,
      plugin_module: Jido.Connect.Google.Analytics.Plugin,
      plugin_name: "google_analytics"
    )

    ConnectorContracts.assert_plugin_tool_availability(Analytics)
  end

  test "loads Analytics Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@analytics_dsl_fragments)
  end

  test "invokes get metadata through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@analytics_readonly_scope])

    assert {:ok,
            %{
              metadata_name: "properties/1234/metadata",
              dimensions: [%{name: "country", display_name: "Country"}],
              metrics: [%{name: "activeUsers", type: "TYPE_INTEGER"}],
              comparisons: []
            }} =
             Connect.invoke(
               Analytics.integration(),
               "google.analytics.metadata.get",
               %{property: "1234"},
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts) do
    scopes = Keyword.get(opts, :scopes, [@analytics_readonly_scope])

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
        fields: %{access_token: "token", google_analytics_client: FakeAnalyticsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
