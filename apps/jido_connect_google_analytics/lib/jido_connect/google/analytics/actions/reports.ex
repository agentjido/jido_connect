defmodule Jido.Connect.Google.Analytics.Actions.Reports do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/analytics.readonly"
  @scope_resolver Jido.Connect.Google.Analytics.ScopeResolver

  actions do
    action :run_report do
      id("google.analytics.report.run")
      resource(:report)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Run Analytics report")
      description("Run a Google Analytics Data API report for one GA4 property.")
      handler(Jido.Connect.Google.Analytics.Handlers.Actions.RunReport)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:property, :string,
          required?: true,
          example: "properties/1234"
        )

        field(:date_ranges, {:array, :map},
          required?: true,
          example: [%{start_date: "7daysAgo", end_date: "yesterday"}]
        )

        field(:metrics, {:array, :string},
          required?: true,
          example: ["activeUsers"]
        )

        field(:dimensions, {:array, :string}, default: [])
        field(:dimension_filter, :map)
        field(:metric_filter, :map)
        field(:order_bys, {:array, :map}, default: [])
        field(:metric_aggregations, {:array, :string}, default: [])
        field(:comparisons, {:array, :map}, default: [])
        field(:cohort_spec, :map)
        field(:limit, :integer)
        field(:offset, :integer)
        field(:currency_code, :string)
        field(:keep_empty_rows, :boolean)
        field(:return_property_quota, :boolean)
      end

      output do
        field(:report, :map)
      end
    end

    action :batch_run_reports do
      id("google.analytics.report.batch_run")
      resource(:report)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Batch run Analytics reports")
      description("Run up to five Google Analytics Data API reports for one GA4 property.")
      handler(Jido.Connect.Google.Analytics.Handlers.Actions.BatchRunReports)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:property, :string,
          required?: true,
          example: "properties/1234"
        )

        field(:requests, {:array, :map},
          required?: true,
          example: [
            %{
              date_ranges: [%{start_date: "7daysAgo", end_date: "yesterday"}],
              metrics: ["activeUsers"],
              dimensions: ["country"]
            }
          ]
        )
      end

      output do
        field(:reports, {:array, :map})
        field(:kind, :string)
      end
    end
  end
end
