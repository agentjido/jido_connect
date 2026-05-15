defmodule Jido.Connect.Google.SearchConsole.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Normalizer
  alias Jido.Connect.Google.SearchConsole.{Row, SearchReport, Site}

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
end
