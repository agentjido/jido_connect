defmodule Jido.Connect.PostHog.Actions.Insights do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :list_insights do
      id("posthog.insight.list")
      resource(:insight)
      verb(:list)
      data_classification(:workspace_content)
      label("List insights")
      description("List insights saved in a PostHog project.")
      handler(Jido.Connect.PostHog.Handlers.Actions.ListInsights)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["insights:read"], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer,
          default: 100,
          description: "Maximum number of insights to return."
        )

        field(:offset, :integer, default: 0, description: "Pagination offset.")
      end

      output do
        field(:insights, {:array, :map})
        field(:next, :string)
      end
    end

    action :get_insight do
      id("posthog.insight.get")
      resource(:insight)
      verb(:get)
      data_classification(:workspace_content)
      label("Get insight")
      description("Fetch a single PostHog insight by short ID.")
      handler(Jido.Connect.PostHog.Handlers.Actions.GetInsight)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["insights:read"], resolver: @scope_resolver)
      end

      input do
        field(:insight_id, :string, required?: true, description: "Insight short ID.")

        field(:fields, {:array, :string},
          default: nil,
          description: "List of fields to return."
        )
      end

      output do
        field(:id, :string)
        field(:short_id, :string)
        field(:name, :string)
        field(:derived_name, :string)
        field(:type, :string)
        field(:result, :map)
        field(:created_at, :string)
        field(:updated_at, :string)
      end
    end
  end
end
