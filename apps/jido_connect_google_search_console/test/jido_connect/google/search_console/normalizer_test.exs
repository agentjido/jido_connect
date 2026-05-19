defmodule Jido.Connect.Google.SearchConsole.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Normalizer
  alias Jido.Connect.Google.SearchConsole.{Row, SearchReport, Sitemap, Site, URLInspection}

  test "normalizes a site payload with permission level" do
    payload = %{
      "siteUrl" => "https://example.com/",
      "permissionLevel" => "siteOwner"
    }

    assert {:ok, %Site{} = site} = Normalizer.site(payload)
    assert site.site_url == "https://example.com/"
    assert site.permission_level == "siteOwner"
  end

  test "normalizes a site payload without optional fields" do
    payload = %{
      "siteUrl" => "https://example.com/"
    }

    assert {:ok, %Site{} = site} = Normalizer.site(payload)
    assert site.site_url == "https://example.com/"
  end

  test "returns error for invalid payload" do
    assert {:error, :invalid_site_payload} = Normalizer.site("not a map")
    assert {:error, :invalid_site_payload} = Normalizer.site(nil)
  end

  test "returns error for payload missing siteUrl" do
    assert {:error, _} = Normalizer.site(%{permissionLevel: "siteOwner"})
  end

  test "normalizes a search report payload with rows" do
    payload = %{
      "rows" => [
        %{
          "keys" => ["seo tips"],
          "clicks" => 10,
          "impressions" => 200,
          "ctr" => 0.05,
          "position" => 2.1
        }
      ],
      "responseAggregationType" => "auto"
    }

    assert {:ok, %SearchReport{} = report} = Normalizer.search_report(payload)
    assert [%Row{} = row] = report.rows
    assert row.keys == ["seo tips"]
    assert row.clicks == 10
    assert row.impressions == 200
    assert row.ctr == 0.05
    assert row.position == 2.1
    assert report.response_aggregation_type == "auto"
  end

  test "normalizes a search report payload without rows" do
    payload = %{"responseAggregationType" => "byPage"}

    assert {:ok, %SearchReport{} = report} = Normalizer.search_report(payload)
    assert report.rows == []
    assert report.response_aggregation_type == "byPage"
  end

  test "normalizes a search report with empty rows array" do
    assert {:ok, %SearchReport{} = report} = Normalizer.search_report(%{"rows" => []})
    assert report.rows == []
  end

  test "returns error for invalid search report payload" do
    assert {:error, :invalid_search_report_payload} = Normalizer.search_report("not a map")
    assert {:error, :invalid_search_report_payload} = Normalizer.search_report(nil)
  end

  describe "sitemap normalization" do
    test "normalizes a sitemap payload with full metadata" do
      payload = %{
        "path" => "https://example.com/sitemap.xml",
        "lastSubmitted" => "2026-01-15T10:30:00Z",
        "isPending" => false,
        "lastDownloaded" => "2026-01-15T11:00:00Z",
        "errors" => [%{"message" => "error1"}],
        "warnings" => [%{"message" => "warn1"}, %{"message" => "warn2"}],
        "type" => "SITEMAP",
        "contents" => [%{"type" => "web", "submitted" => 42, "indexed" => 40}]
      }

      assert {:ok, %Sitemap{} = sitemap} = Normalizer.sitemap(payload)
      assert sitemap.path == "https://example.com/sitemap.xml"
      assert sitemap.last_submitted == "2026-01-15T10:30:00Z"
      assert sitemap.is_pending == false
      assert sitemap.last_downloaded == "2026-01-15T11:00:00Z"
      assert sitemap.error_count == 1
      assert sitemap.warnings_count == 2
      assert sitemap.type == "SITEMAP"
      assert length(sitemap.contents) == 1
    end

    test "normalizes a sitemap payload with minimal fields" do
      payload = %{
        "path" => "https://example.com/sitemap.xml"
      }

      assert {:ok, %Sitemap{} = sitemap} = Normalizer.sitemap(payload)
      assert sitemap.path == "https://example.com/sitemap.xml"
      assert sitemap.is_pending == false
      assert sitemap.error_count == 0
      assert sitemap.warnings_count == 0
      assert sitemap.contents == []
    end

    test "returns error for invalid sitemap payload" do
      assert {:error, :invalid_sitemap_payload} = Normalizer.sitemap("not a map")
      assert {:error, :invalid_sitemap_payload} = Normalizer.sitemap(nil)
    end

    test "returns error for payload missing path" do
      assert {:error, _} = Normalizer.sitemap(%{"type" => "SITEMAP"})
    end

    test "counts errors and warnings from lists" do
      payload = %{
        "path" => "https://example.com/sitemap.xml",
        "errors" => [%{"message" => "e1"}, %{"message" => "e2"}, %{"message" => "e3"}],
        "warnings" => [%{"message" => "w1"}]
      }

      assert {:ok, %Sitemap{} = sitemap} = Normalizer.sitemap(payload)
      assert sitemap.error_count == 3
      assert sitemap.warnings_count == 1
    end

    test "handles non-list errors and warnings gracefully" do
      payload = %{
        "path" => "https://example.com/sitemap.xml",
        "errors" => "not a list",
        "warnings" => 42
      }

      assert {:ok, %Sitemap{} = sitemap} = Normalizer.sitemap(payload)
      assert sitemap.error_count == 0
      assert sitemap.warnings_count == 0
    end
  end

  describe "url_inspection normalization" do
    test "normalizes a URL inspection payload with full results" do
      payload = %{
        "inspectionResult" => %{
          "inspectionResultLink" => "https://search.google.com/search-console/inspect?id=xyz",
          "indexStatusResult" => %{
            "verdict" => "PASS",
            "coverageState" => "Submitted and indexed",
            "robotsTxtState" => "ALLOWED",
            "pageFetchState" => "SUCCESSFUL"
          },
          "ampResult" => %{"verdict" => "PASS"},
          "mobileUsabilityResult" => %{"verdict" => "PASS"},
          "richResultsResult" => %{
            "detectedItems" => [
              %{"richResultType" => "Logos"}
            ]
          }
        }
      }

      assert {:ok, %URLInspection{} = inspection} = Normalizer.url_inspection(payload)

      assert inspection.inspection_result_link ==
               "https://search.google.com/search-console/inspect?id=xyz"

      assert inspection.index_status == %{
               "verdict" => "PASS",
               "coverageState" => "Submitted and indexed",
               "robotsTxtState" => "ALLOWED",
               "pageFetchState" => "SUCCESSFUL"
             }

      assert inspection.amp_result == %{"verdict" => "PASS"}
      assert inspection.mobile_usability_result == %{"verdict" => "PASS"}
      assert length(inspection.rich_results) == 1
    end

    test "normalizes a URL inspection payload with minimal fields" do
      payload = %{"inspectionResult" => %{}}

      assert {:ok, %URLInspection{} = inspection} = Normalizer.url_inspection(payload)
      assert inspection.inspection_result_link == nil
      assert inspection.index_status == %{}
      assert inspection.rich_results == []
    end

    test "normalizes a URL inspection with missing inspectionResult" do
      assert {:ok, %URLInspection{} = inspection} = Normalizer.url_inspection(%{})
      assert inspection.inspection_result_link == nil
      assert inspection.index_status == %{}
      assert inspection.rich_results == []
    end

    test "returns error for invalid URL inspection payload" do
      assert {:error, :invalid_url_inspection_payload} =
               Normalizer.url_inspection("not a map")

      assert {:error, :invalid_url_inspection_payload} = Normalizer.url_inspection(nil)
    end

    test "handles non-list richResults detectedItems gracefully" do
      payload = %{
        "inspectionResult" => %{
          "richResultsResult" => %{"detectedItems" => "not a list"}
        }
      }

      assert {:ok, %URLInspection{} = inspection} = Normalizer.url_inspection(payload)
      assert inspection.rich_results == []
    end
  end
end
