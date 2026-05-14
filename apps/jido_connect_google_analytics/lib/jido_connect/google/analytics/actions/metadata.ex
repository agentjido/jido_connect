defmodule Jido.Connect.Google.Analytics.Actions.Metadata do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/analytics.readonly"
  @scope_resolver Jido.Connect.Google.Analytics.ScopeResolver

  actions do
    action :get_metadata do
      id("google.analytics.metadata.get")
      resource(:metadata)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Analytics metadata")
      description("List available Google Analytics dimensions and metrics for a GA4 property.")
      handler(Jido.Connect.Google.Analytics.Handlers.Actions.GetMetadata)
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

        field(:fields, :string)
      end

      output do
        field(:metadata_name, :string)
        field(:dimensions, {:array, :map})
        field(:metrics, {:array, :map})
        field(:comparisons, {:array, :map})
      end
    end
  end
end
