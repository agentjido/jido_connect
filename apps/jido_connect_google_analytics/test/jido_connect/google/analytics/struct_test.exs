defmodule Jido.Connect.Google.Analytics.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Analytics.{
    Dimension,
    Metric,
    PropertySummary,
    Report,
    Row
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "dimension struct validates descriptors and row values with Zoi" do
    dimension =
      ConnectorContracts.assert_struct_defaults(
        Dimension,
        %{
          name: "country",
          value: "United States",
          display_name: "Country",
          description: "The country where activity occurred.",
          category: "Geography"
        },
        deprecated_api_names: [],
        custom?: false,
        deprecated?: false,
        metadata: %{}
      )

    assert dimension.value == "United States"
    assert {:error, _error} = Dimension.new(%{})
  end

  test "metric struct validates descriptors and row values with Zoi" do
    metric =
      ConnectorContracts.assert_struct_defaults(
        Metric,
        %{
          name: "activeUsers",
          value: "42",
          type: "TYPE_INTEGER",
          display_name: "Active users",
          expression: "activeUsers"
        },
        deprecated_api_names: [],
        blocked_reasons: [],
        custom?: false,
        deprecated?: false,
        metadata: %{}
      )

    assert metric.type == "TYPE_INTEGER"
    assert {:error, _error} = Metric.new(%{})
  end

  test "row struct validates nested dimensions and metrics with Zoi" do
    row =
      ConnectorContracts.assert_struct_defaults(
        Row,
        %{
          dimensions: [%{name: "country", value: "United States"}],
          metrics: [%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
        },
        metadata: %{}
      )

    assert [%Dimension{name: "country"}] = row.dimensions
    assert [%Metric{name: "activeUsers"}] = row.metrics
  end

  test "report struct validates nested report payloads with Zoi" do
    report =
      ConnectorContracts.assert_struct_defaults(
        Report,
        %{
          property: "properties/1234",
          dimension_headers: [%{name: "country", display_name: "Country"}],
          metric_headers: [%{name: "activeUsers", type: "TYPE_INTEGER"}],
          rows: [
            %{
              dimensions: [%{name: "country", value: "United States"}],
              metrics: [%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
            }
          ],
          totals: [
            %{
              metrics: [%{name: "activeUsers", value: "42", type: "TYPE_INTEGER"}]
            }
          ],
          row_count: 1,
          currency_code: "USD",
          time_zone: "America/Chicago",
          property_quota: %{"tokensPerDay" => %{"remaining" => 24_000}}
        },
        maximums: [],
        minimums: [],
        metadata: %{}
      )

    assert [%Dimension{name: "country"}] = report.dimension_headers
    assert [%Row{} = row] = report.rows
    assert [%Metric{name: "activeUsers", value: "42"}] = row.metrics
  end

  test "report struct defaults optional collections" do
    report =
      ConnectorContracts.assert_struct_defaults(
        Report,
        %{},
        dimension_headers: [],
        metric_headers: [],
        rows: [],
        totals: [],
        maximums: [],
        minimums: [],
        row_count: 0,
        metadata: %{},
        property_quota: %{}
      )

    assert report.property == nil
  end

  test "property summary struct validates Admin API property metadata with Zoi" do
    summary =
      ConnectorContracts.assert_struct_defaults(
        PropertySummary,
        %{
          property: "properties/1234",
          display_name: "Jido Web",
          property_type: "PROPERTY_TYPE_ORDINARY",
          parent: "accountSummaries/123",
          account: "accounts/123"
        },
        metadata: %{}
      )

    assert summary.display_name == "Jido Web"
    assert {:error, _error} = PropertySummary.new(%{})
  end
end
