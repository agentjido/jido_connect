defmodule Jido.Connect.Google.Analytics.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Analytics.{Dimension, Metric, Normalizer}

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
end
