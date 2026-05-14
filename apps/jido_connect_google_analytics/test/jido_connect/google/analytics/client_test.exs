defmodule Jido.Connect.Google.Analytics.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Analytics.{Client, Dimension, Metric, Report}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_data_api_base_url,
      "https://analytics-data.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_analytics, :google_analytics_data_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets Analytics metadata for a property" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1beta/properties/1234/metadata"
      assert conn.query_params["fields"] == "dimensions(apiName,uiName),metrics(apiName,uiName)"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, %{
        "name" => "properties/1234/metadata",
        "dimensions" => [
          %{
            "apiName" => "country",
            "uiName" => "Country",
            "description" => "The country where activity occurred.",
            "category" => "Geography",
            "customDefinition" => false
          }
        ],
        "metrics" => [
          %{
            "apiName" => "activeUsers",
            "uiName" => "Active users",
            "description" => "The number of active users.",
            "category" => "User",
            "type" => "TYPE_INTEGER",
            "customDefinition" => false
          }
        ],
        "comparisons" => [%{"apiName" => "allUsers"}]
      })
    end)

    assert {:ok,
            %{
              metadata_name: "properties/1234/metadata",
              dimensions: [%Dimension{name: "country", display_name: "Country"}],
              metrics: [%Metric{name: "activeUsers", type: "TYPE_INTEGER"}],
              comparisons: [%{"apiName" => "allUsers"}]
            }} =
             Client.get_metadata(
               %{
                 property: "properties/1234",
                 fields: "dimensions(apiName,uiName),metrics(apiName,uiName)"
               },
               "token"
             )
  end

  test "returns provider errors for invalid metadata success payloads" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"dimensions" => :invalid})
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.get_metadata(%{property: "properties/1234"}, "token")
  end

  test "runs Analytics reports for a property" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1beta/properties/1234:runReport"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "dateRanges" => [%{"startDate" => "7daysAgo", "endDate" => "yesterday"}],
               "dimensions" => [%{"name" => "country"}],
               "metrics" => [%{"name" => "activeUsers"}],
               "limit" => "100"
             }

      Req.Test.json(conn, report_payload())
    end)

    assert {:ok,
            %Report{row_count: 1, rows: [row], metric_headers: [%Metric{name: "activeUsers"}]}} =
             Client.run_report(
               %{
                 property: "properties/1234",
                 body: %{
                   "dateRanges" => [%{"startDate" => "7daysAgo", "endDate" => "yesterday"}],
                   "dimensions" => [%{"name" => "country"}],
                   "metrics" => [%{"name" => "activeUsers"}],
                   "limit" => "100"
                 }
               },
               "token"
             )

    assert [%Dimension{name: "country", value: "US"}] = row.dimensions
    assert [%Metric{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}] = row.metrics
  end

  test "batch runs Analytics reports for a property" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1beta/properties/1234:batchRunReports"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "requests" => [
                 %{
                   "dateRanges" => [%{"startDate" => "7daysAgo", "endDate" => "yesterday"}],
                   "metrics" => [%{"name" => "activeUsers"}]
                 }
               ]
             }

      Req.Test.json(conn, %{
        "kind" => "analyticsData#batchRunReports",
        "reports" => [report_payload()]
      })
    end)

    assert {:ok, %{kind: "analyticsData#batchRunReports", reports: [%Report{row_count: 1}]}} =
             Client.batch_run_reports(
               %{
                 property: "properties/1234",
                 body: %{
                   "requests" => [
                     %{
                       "dateRanges" => [%{"startDate" => "7daysAgo", "endDate" => "yesterday"}],
                       "metrics" => [%{"name" => "activeUsers"}]
                     }
                   ]
                 }
               },
               "token"
             )
  end

  test "returns provider errors for invalid report success payloads" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"rows" => :invalid})
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.run_report(%{property: "properties/1234", body: %{}}, "token")
  end

  defp report_payload do
    %{
      "dimensionHeaders" => [%{"name" => "country"}],
      "metricHeaders" => [%{"name" => "activeUsers", "type" => "TYPE_INTEGER"}],
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "US"}],
          "metricValues" => [%{"value" => "42"}]
        }
      ],
      "metadata" => %{"currencyCode" => "USD", "timeZone" => "America/Chicago"},
      "propertyQuota" => %{"tokensPerDay" => %{"remaining" => 199_990}},
      "rowCount" => 1
    }
  end
end
