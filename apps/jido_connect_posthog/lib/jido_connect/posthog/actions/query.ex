defmodule Jido.Connect.PostHog.Actions.Query do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :run_query do
      id("posthog.query.run")
      resource(:query)
      verb(:create)
      data_classification(:workspace_content)
      label("Run HogQL query")

      description(
        "Execute a HogQL query against a PostHog project and return normalized results."
      )

      handler(Jido.Connect.PostHog.Handlers.Actions.RunQuery)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["insights:read"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string,
          required?: true,
          description: "HogQL query string to execute."
        )

        field(:date_from, :string,
          default: nil,
          description: "Start date for date range filter (ISO 8601 or relative like '-30d')."
        )

        field(:date_to, :string,
          default: nil,
          description: "End date for date range filter (ISO 8601 or relative like '-1d')."
        )
      end

      output do
        field(:query, :string)
        field(:columns, {:array, :string})
        field(:results, {:array, :map})
        field(:has_more, :boolean)
      end
    end
  end
end
