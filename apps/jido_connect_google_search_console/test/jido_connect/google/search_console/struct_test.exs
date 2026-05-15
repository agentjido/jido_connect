defmodule Jido.Connect.Google.SearchConsole.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.{
    Row,
    SearchReport,
    Site,
    Sitemap,
    URLInspection
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "site struct validates with Zoi" do
    site =
      ConnectorContracts.assert_struct_defaults(
        Site,
        %{site_url: "https://example.com/"},
        metadata: %{}
      )

    assert site.site_url == "https://example.com/"
    assert {:error, _error} = Site.new(%{})
  end

  test "site struct accepts optional permission level" do
    site =
      ConnectorContracts.assert_struct_defaults(
        Site,
        %{site_url: "https://example.com/", permission_level: "siteOwner"},
        metadata: %{}
      )

    assert site.permission_level == "siteOwner"
  end

  test "row struct validates with Zoi" do
    row =
      ConnectorContracts.assert_struct_defaults(
        Row,
        %{
          keys: ["https://example.com/page"],
          clicks: 42,
          impressions: 1000,
          ctr: 0.042,
          position: 3.5
        },
        metadata: %{}
      )

    assert row.keys == ["https://example.com/page"]
    assert row.clicks == 42
    assert row.impressions == 1000
    assert row.ctr == 0.042
    assert row.position == 3.5
  end

  test "row struct defaults numeric fields" do
    row =
      ConnectorContracts.assert_struct_defaults(
        Row,
        %{},
        keys: [],
        clicks: 0,
        impressions: 0,
        ctr: 0.0,
        position: 0.0,
        metadata: %{}
      )

    assert row.keys == []
    assert row.clicks == 0
  end

  test "search report struct validates with Zoi" do
    report =
      ConnectorContracts.assert_struct_defaults(
        SearchReport,
        %{
          site_url: "https://example.com/",
          rows: [
            %{keys: ["query1"], clicks: 10, impressions: 200, ctr: 0.05, position: 2.1}
          ],
          response_aggregation_type: "auto"
        },
        metadata: %{}
      )

    assert report.site_url == "https://example.com/"
    assert [%Row{} = row] = report.rows
    assert row.clicks == 10
    assert report.response_aggregation_type == "auto"
  end

  test "search report struct defaults optional collections" do
    report =
      ConnectorContracts.assert_struct_defaults(
        SearchReport,
        %{},
        rows: [],
        metadata: %{}
      )

    assert report.site_url == nil
    assert report.rows == []
    assert report.response_aggregation_type == nil
  end

  test "sitemap struct validates with Zoi" do
    sitemap =
      ConnectorContracts.assert_struct_defaults(
        Sitemap,
        %{path: "https://example.com/sitemap.xml"},
        is_pending: false,
        error_count: 0,
        warnings_count: 0,
        contents: [],
        metadata: %{}
      )

    assert sitemap.path == "https://example.com/sitemap.xml"
    assert {:error, _error} = Sitemap.new(%{})
  end

  test "sitemap struct accepts full sitemap metadata" do
    sitemap =
      ConnectorContracts.assert_struct_defaults(
        Sitemap,
        %{
          path: "https://example.com/sitemap.xml",
          last_submitted: "2026-01-15T10:30:00Z",
          is_pending: false,
          last_downloaded: "2026-01-15T11:00:00Z",
          error_count: 0,
          warnings_count: 1,
          type: "SITEMAP",
          contents: [%{"type" => "web", "submitted" => 42, "indexed" => 40}]
        },
        metadata: %{}
      )

    assert sitemap.last_submitted == "2026-01-15T10:30:00Z"
    assert sitemap.warnings_count == 1
    assert sitemap.type == "SITEMAP"
    assert length(sitemap.contents) == 1
  end

  test "URL inspection struct validates with Zoi" do
    inspection =
      ConnectorContracts.assert_struct_defaults(
        URLInspection,
        %{
          inspection_result_link:
            "https://search.google.com/search-console/inspect?resource_id=sc-domain:example.com&id=xyz",
          index_status: %{"coverageState" => "Submitted and indexed"},
          mobile_usability_result: %{"verdict" => "PASS"}
        },
        amp_result: %{},
        rich_results: [],
        metadata: %{}
      )

    assert inspection.index_status == %{"coverageState" => "Submitted and indexed"}
    assert inspection.mobile_usability_result == %{"verdict" => "PASS"}
  end

  test "URL inspection struct defaults optional fields" do
    inspection =
      ConnectorContracts.assert_struct_defaults(
        URLInspection,
        %{},
        index_status: %{},
        amp_result: %{},
        mobile_usability_result: %{},
        rich_results: [],
        metadata: %{}
      )

    assert inspection.inspection_result_link == nil
    assert inspection.index_status == %{}
    assert inspection.rich_results == []
  end
end
