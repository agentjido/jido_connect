defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.QuerySearchAnalyticsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.QuerySearchAnalytics
  alias Jido.Connect.Google.SearchConsole.SearchReport

  defmodule FakeSearchAnalyticsClient do
    def query_search_analytics(%{site_url: "https://example.com/", body: body}, "token") do
      {:ok,
       SearchReport.new!(%{
         site_url: "https://example.com/",
         rows: [
           %{
             keys: ["seo tips"],
             clicks: 10,
             impressions: 200,
             ctr: 0.05,
             position: 2.1
           }
         ],
         response_aggregation_type: Map.get(body, "aggregationType", "auto")
       })}
    end
  end

  @fake_credentials %{
    access_token: "token",
    google_search_console_client: FakeSearchAnalyticsClient
  }

  describe "run/2 date range validation" do
    test "returns error when start_date is missing" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{site_url: "https://example.com/", end_date: "2026-01-31"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when end_date is missing" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{site_url: "https://example.com/", start_date: "2026-01-01"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when start_date has invalid format" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "not-a-date",
                   end_date: "2026-01-31"
                 },
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when end_date has invalid format" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "Jan 31, 2026"
                 },
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "accepts valid ISO 8601 dates" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31"
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end

  describe "run/2 site_url validation" do
    test "returns error when site_url is missing" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{start_date: "2026-01-01", end_date: "2026-01-31"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when site_url is empty" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{site_url: "", start_date: "2026-01-01", end_date: "2026-01-31"},
                 %{credentials: %{access_token: "token"}}
               )
    end
  end

  describe "run/2 dimensions validation" do
    test "returns error for invalid dimension value" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: ["invalid_dimension"]
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error when dimensions exceeds limit of 3" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: ["query", "page", "country", "device"]
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error when dimension is not a string" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: [123]
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid dimensions" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: ["query", "page"]
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts all valid dimension values" do
      for dim <- ["query", "page", "country", "device", "searchAppearance"] do
        assert {:ok, %{report: %{rows: [_ | _]}}} =
                 QuerySearchAnalytics.run(
                   %{
                     site_url: "https://example.com/",
                     start_date: "2026-01-01",
                     end_date: "2026-01-31",
                     dimensions: [dim]
                   },
                   %{credentials: @fake_credentials}
                 )
      end
    end

    test "normalizes snake_case dimension to camelCase" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: ["search_appearance"]
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end

  describe "run/2 search_type validation" do
    test "defaults to web when search_type is omitted" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error for invalid search_type" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   search_type: "podcast"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts all valid search types" do
      for st <- ["web", "image", "video", "news", "discover", "googleNews"] do
        assert {:ok, %{report: %{rows: [_ | _]}}} =
                 QuerySearchAnalytics.run(
                   %{
                     site_url: "https://example.com/",
                     start_date: "2026-01-01",
                     end_date: "2026-01-31",
                     search_type: st
                   },
                   %{credentials: @fake_credentials}
                 )
      end
    end
  end

  describe "run/2 row_limit validation" do
    test "returns error when row_limit is below minimum" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   row_limit: 0
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error when row_limit exceeds maximum (25000)" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   row_limit: 25_001
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error when row_limit is not an integer" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   row_limit: "lots"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid row_limit" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   row_limit: 500
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts maximum row_limit of 25000" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   row_limit: 25_000
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end

  describe "run/2 start_row validation" do
    test "returns error when start_row is negative" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   start_row: -1
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "returns error when start_row is not an integer" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   start_row: "zero"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid start_row" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   start_row: 100
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end

  describe "run/2 dimension_filter_groups validation" do
    test "returns error when dimension_filter_groups contains non-map" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimension_filter_groups: ["not a map"]
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid dimension_filter_groups" do
      assert {:ok, %{report: %{rows: [_ | _]}}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimension_filter_groups: [
                     %{
                       "groupType" => "and",
                       "filters" => [
                         %{
                           "dimension" => "query",
                           "operator" => "contains",
                           "expression" => "elixir"
                         }
                       ]
                     }
                   ]
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end

  describe "run/2 aggregation_type validation" do
    test "returns error for invalid aggregation_type" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   aggregation_type: "invalid"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid aggregation_type" do
      for at <- ["auto", "byProperty", "byPage", "by_news_property"] do
        assert {:ok, %{report: %{rows: [_ | _]}}} =
                 QuerySearchAnalytics.run(
                   %{
                     site_url: "https://example.com/",
                     start_date: "2026-01-01",
                     end_date: "2026-01-31",
                     aggregation_type: at
                   },
                   %{credentials: @fake_credentials}
                 )
      end
    end
  end

  describe "run/2 data_state validation" do
    test "returns error for invalid data_state" do
      assert {:error, %{reason: :invalid_search_analytics_query}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   data_state: "partial"
                 },
                 %{credentials: @fake_credentials}
               )
    end

    test "accepts valid data_state" do
      for ds <- ["all", "final"] do
        assert {:ok, %{report: %{rows: [_ | _]}}} =
                 QuerySearchAnalytics.run(
                   %{
                     site_url: "https://example.com/",
                     start_date: "2026-01-01",
                     end_date: "2026-01-31",
                     data_state: ds
                   },
                   %{credentials: @fake_credentials}
                 )
      end
    end
  end

  describe "run/2 successful query" do
    test "returns normalized search report with rows" do
      assert {:ok, %{report: report}} =
               QuerySearchAnalytics.run(
                 %{
                   site_url: "https://example.com/",
                   start_date: "2026-01-01",
                   end_date: "2026-01-31",
                   dimensions: ["query"],
                   search_type: "web"
                 },
                 %{credentials: @fake_credentials}
               )

      assert is_map(report)
      assert report.site_url == "https://example.com/"
      assert length(report.rows) == 1
      assert hd(report.rows).keys == ["seo tips"]
      assert hd(report.rows).clicks == 10
      assert hd(report.rows).impressions == 200
    end
  end
end
