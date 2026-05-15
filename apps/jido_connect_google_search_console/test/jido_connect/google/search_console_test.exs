defmodule Jido.Connect.Google.SearchConsoleTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.SearchConsole
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"

  @action_modules [
    Jido.Connect.Google.SearchConsole.Actions.ListSites,
    Jido.Connect.Google.SearchConsole.Actions.AddSite,
    Jido.Connect.Google.SearchConsole.Actions.QuerySearchAnalytics,
    Jido.Connect.Google.SearchConsole.Actions.ListSitemaps,
    Jido.Connect.Google.SearchConsole.Actions.SubmitSitemap,
    Jido.Connect.Google.SearchConsole.Actions.InspectUrl
  ]

  @dsl_fragments [
    Jido.Connect.Google.SearchConsole.Actions.Sites,
    Jido.Connect.Google.SearchConsole.Actions.SearchAnalytics,
    Jido.Connect.Google.SearchConsole.Actions.Sitemaps,
    Jido.Connect.Google.SearchConsole.Actions.URLInspection
  ]

  defmodule FakeSearchConsoleClient do
    def list_sites(%{}, "token") do
      {:ok,
       %{
         sites: [
           SearchConsole.Site.new!(%{
             site_url: "https://example.com/",
             permission_level: "siteOwner"
           }),
           SearchConsole.Site.new!(%{
             site_url: "https://example.org/",
             permission_level: "siteRestrictedUser"
           })
         ]
       }}
    end

    def add_site(%{site_url: "https://new-site.com/"}, "token") do
      {:ok,
       SearchConsole.Site.new!(%{
         site_url: "https://new-site.com/",
         permission_level: "siteOwner"
       })}
    end

    def query_search_analytics(%{site_url: "https://example.com/"}, "token") do
      {:ok,
       SearchConsole.SearchReport.new!(%{
         site_url: "https://example.com/",
         rows: [
           %{keys: ["seo tips"], clicks: 10, impressions: 200, ctr: 0.05, position: 2.1}
         ],
         response_aggregation_type: "auto"
       })}
    end

    def list_sitemaps(%{site_url: "https://example.com/"}, "token") do
      {:ok,
       %{
         sitemaps: [
           SearchConsole.Sitemap.new!(%{
             path: "https://example.com/sitemap.xml",
             last_submitted: "2026-01-15T10:30:00Z",
             is_pending: false,
             error_count: 0,
             warnings_count: 1,
             type: "SITEMAP"
           })
         ]
       }}
    end

    def submit_sitemap(
          %{site_url: "https://example.com/", sitemap_path: "https://example.com/sitemap.xml"},
          "token"
        ) do
      {:ok, %{path: "https://example.com/sitemap.xml", submitted: true}}
    end

    def inspect_url(
          %{site_url: "https://example.com/", inspection_url: "https://example.com/page"},
          "token"
        ) do
      {:ok,
       SearchConsole.URLInspection.new!(%{
         inspection_result_link:
           "https://search.google.com/search-console/inspect?id=xyz",
         index_status: %{"verdict" => "PASS", "coverageState" => "Submitted and indexed"},
         mobile_usability_result: %{"verdict" => "PASS"},
         rich_results: []
       })}
    end
  end

  test "declares Google Search Console provider metadata" do
    spec = SearchConsole.integration()

    assert spec.id == :google_search_console
    assert spec.package == :jido_connect_google_search_console
    assert spec.name == "Google Search Console"
    assert spec.category == :marketing
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :search, :seo, :marketing]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.search_console.site.list",
             "google.search_console.site.add",
             "google.search_console.search_analytics.query",
             "google.search_console.sitemap.list",
             "google.search_console.sitemap.submit",
             "google.search_console.url_inspection.inspect"
           ]

    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(SearchConsole,
      otp_app: :jido_connect_google_search_console,
      action_modules: @action_modules,
      plugin_module: Jido.Connect.Google.SearchConsole.Plugin,
      plugin_name: "google_search_console"
    )

    ConnectorContracts.assert_plugin_tool_availability(SearchConsole)
  end

  test "loads Search Console Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@dsl_fragments)
  end

  test "invokes list sites through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])

    assert {:ok,
            %{
              sites: [
                %{site_url: "https://example.com/", permission_level: "siteOwner"},
                %{site_url: "https://example.org/", permission_level: "siteRestrictedUser"}
              ]
            }} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.site.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes add site through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@write_scope])

    assert {:ok,
            %{
              site: %{
                site_url: "https://new-site.com/",
                permission_level: "siteOwner"
              }
            }} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.site.add",
               %{site_url: "https://new-site.com/"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes query search analytics through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])

    assert {:ok, %{report: %{site_url: "https://example.com/", rows: [_ | _]}}} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.search_analytics.query",
               %{
                 site_url: "https://example.com/",
                 start_date: "2026-01-01",
                 end_date: "2026-01-31"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list sitemaps through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])

    assert {:ok, %{sitemaps: [%{path: "https://example.com/sitemap.xml"}]}} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.sitemap.list",
               %{site_url: "https://example.com/"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes submit sitemap through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@write_scope])

    assert {:ok, %{path: "https://example.com/sitemap.xml", submitted: true}} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.sitemap.submit",
               %{
                 site_url: "https://example.com/",
                 sitemap_path: "https://example.com/sitemap.xml"
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes inspect URL through injected client and lease" do
    {context, lease} = context_and_lease(scopes: [@readonly_scope])

    assert {:ok, %{inspection: inspection}} =
             Connect.invoke(
               SearchConsole.integration(),
               "google.search_console.url_inspection.inspect",
               %{
                 site_url: "https://example.com/",
                 inspection_url: "https://example.com/page"
               },
               context: context,
               credential_lease: lease
             )

    assert inspection.inspection_result_link ==
             "https://search.google.com/search-console/inspect?id=xyz"

    assert inspection.index_status == %{
             "verdict" => "PASS",
             "coverageState" => "Submitted and indexed"
           }

    assert inspection.mobile_usability_result == %{"verdict" => "PASS"}
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
        fields: %{access_token: "token", google_search_console_client: FakeSearchConsoleClient},
        scopes: scopes
      })

    {context, lease}
  end
end
