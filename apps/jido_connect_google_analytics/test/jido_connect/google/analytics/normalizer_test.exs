defmodule Jido.Connect.Google.Analytics.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Analytics.{Dimension, Metric, Normalizer, Report, Row}

  test "normalizes Analytics metadata payloads" do
    assert {:ok,
            %{
              metadata_name: "properties/1234/metadata",
              dimensions: [
                %Dimension{
                  name: "customEvent:plan",
                  display_name: "Plan",
                  custom?: true,
                  deprecated_api_names: ["customEvent:old_plan"]
                }
              ],
              metrics: [
                %Metric{
                  name: "activeUsers",
                  display_name: "Active users",
                  type: "TYPE_INTEGER",
                  blocked_reasons: ["NO_REVENUE_METRICS"]
                }
              ]
            }} =
             Normalizer.metadata(%{
               "name" => "properties/1234/metadata",
               "dimensions" => [
                 %{
                   "apiName" => "customEvent:plan",
                   "uiName" => "Plan",
                   "customDefinition" => true,
                   "deprecatedApiNames" => ["customEvent:old_plan"]
                 }
               ],
               "metrics" => [
                 %{
                   "apiName" => "activeUsers",
                   "uiName" => "Active users",
                   "type" => "TYPE_INTEGER",
                   "blockedReasons" => ["NO_REVENUE_METRICS"]
                 }
               ]
             })
  end

  test "rejects invalid metadata payloads" do
    assert {:error, :invalid_metadata_payload} = Normalizer.metadata(:bad)
    assert {:error, :invalid_metadata_collection} = Normalizer.metadata(%{"dimensions" => :bad})

    assert {:error, :invalid_metadata_collection} =
             Normalizer.metadata(%{"dimensions" => [], "metrics" => :bad})

    assert {:error, _error} = Normalizer.dimension(%{"uiName" => "Missing API name"})
    assert {:error, _error} = Normalizer.metric(%{"uiName" => "Missing API name"})
    assert {:error, :invalid_dimension_payload} = Normalizer.dimension(:bad)
    assert {:error, :invalid_metric_payload} = Normalizer.metric(:bad)
  end

  test "normalizes run report payloads" do
    assert {:ok,
            %Report{
              dimension_headers: [%Dimension{name: "country"}],
              metric_headers: [%Metric{name: "activeUsers", type: "TYPE_INTEGER"}],
              rows: [
                %Row{
                  dimensions: [%Dimension{name: "country", value: "US"}],
                  metrics: [%Metric{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
                }
              ],
              totals: [
                %Row{
                  metrics: [%Metric{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
                }
              ],
              row_count: 1,
              currency_code: "USD",
              time_zone: "America/Chicago",
              property_quota: %{"tokensPerDay" => %{"remaining" => 199_990}}
            }} =
             Normalizer.report(%{
               "dimensionHeaders" => [%{"name" => "country"}],
               "metricHeaders" => [%{"name" => "activeUsers", "type" => "TYPE_INTEGER"}],
               "rows" => [
                 %{
                   "dimensionValues" => [%{"value" => "US"}],
                   "metricValues" => [%{"value" => "42"}]
                 }
               ],
               "totals" => [%{"metricValues" => [%{"value" => "42"}]}],
               "metadata" => %{"currencyCode" => "USD", "timeZone" => "America/Chicago"},
               "propertyQuota" => %{"tokensPerDay" => %{"remaining" => 199_990}},
               "rowCount" => 1
             })
  end

  test "normalizes batch report payloads" do
    assert {:ok, %{kind: "analyticsData#batchRunReports", reports: [%Report{row_count: 0}]}} =
             Normalizer.batch_report(%{
               "kind" => "analyticsData#batchRunReports",
               "reports" => [%{"metricHeaders" => [%{"name" => "activeUsers"}]}]
             })
  end

  test "rejects invalid report payloads" do
    assert {:error, :invalid_report_payload} = Normalizer.report(:bad)
    assert {:error, :invalid_report_collection} = Normalizer.report(%{"rows" => :bad})
    assert {:error, :invalid_report_collection} = Normalizer.batch_report(%{"reports" => :bad})
  end
end
