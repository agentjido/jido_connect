defmodule Jido.Connect.PostHog.Actions.FeatureFlags do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :evaluate_feature_flag do
      id("posthog.feature_flag.evaluate")
      resource(:feature_flag)
      verb(:get)
      data_classification(:workspace_content)
      label("Evaluate feature flag")
      description("Evaluate a feature flag for a given distinct ID.")
      handler(Jido.Connect.PostHog.Handlers.Actions.EvaluateFeatureFlag)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["feature_flags:read"], resolver: @scope_resolver)
      end

      input do
        field(:flag_key, :string,
          required?: true,
          description: "Feature flag key to evaluate."
        )

        field(:distinct_id, :string,
          required?: true,
          description: "Distinct ID of the user to evaluate the flag for."
        )

        field(:groups, :map,
          default: %{},
          description: "Group properties for flag evaluation."
        )

        field(:person_properties, :map,
          default: %{},
          description: "Person properties for flag evaluation."
        )
      end

      output do
        field(:flag_key, :string)
        field(:enabled, :boolean)
        field(:variant, :string)
        field(:reason, :string)
        field(:payload, :map)
      end
    end

    action :list_feature_flags do
      id("posthog.feature_flag.list")
      resource(:feature_flag)
      verb(:list)
      data_classification(:workspace_content)
      label("List feature flags")
      description("List feature flags in a PostHog project.")
      handler(Jido.Connect.PostHog.Handlers.Actions.ListFeatureFlags)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["feature_flags:read"], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer,
          default: 100,
          description: "Maximum number of feature flags to return."
        )

        field(:offset, :integer, default: 0, description: "Pagination offset.")
      end

      output do
        field(:flags, {:array, :map})
        field(:next, :string)
      end
    end

    action :get_feature_flag do
      id("posthog.feature_flag.get")
      resource(:feature_flag)
      verb(:get)
      data_classification(:workspace_content)
      label("Get feature flag")
      description("Fetch a single PostHog feature flag by ID.")
      handler(Jido.Connect.PostHog.Handlers.Actions.GetFeatureFlag)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["feature_flags:read"], resolver: @scope_resolver)
      end

      input do
        field(:flag_id, :string, required?: true, description: "Feature flag ID.")
      end

      output do
        field(:id, :string)
        field(:key, :string)
        field(:name, :string)
        field(:description, :string)
        field(:active, :boolean)
        field(:rollout_percentage, :any)
        field(:filters, :map)
        field(:created_at, :string)
      end
    end
  end
end
