defmodule Jido.Connect.Google.SearchConsole.Actions.SearchAnalytics do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @scope_resolver Jido.Connect.Google.SearchConsole.ScopeResolver

  actions do
    action :query_search_analytics do
      id("google.search_console.search_analytics.query")
      resource(:search_analytics)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Query Search Analytics")
      description("Query search analytics data for a site from Google Search Console.")
      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.QuerySearchAnalytics)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:site_url, :string,
          required?: true,
          example: "https://example.com/"
        )

        field(:start_date, :string,
          required?: true,
          example: "2026-01-01"
        )

        field(:end_date, :string,
          required?: true,
          example: "2026-01-31"
        )

        field(:dimensions, {:array, :string},
          default: [],
          example: ["query", "page"]
        )

        field(:search_type, :string,
          default: "web",
          example: "web"
        )

        field(:dimension_filter_groups, {:array, :map}, default: [])

        field(:row_limit, :integer,
          default: 1000,
          example: 1000
        )

        field(:start_row, :integer,
          default: 0,
          example: 0
        )

        field(:aggregation_type, :string, example: "auto")

        field(:data_state, :string, example: "all")
      end

      output do
        field(:report, :map)
      end
    end
  end
end
