defmodule Jido.Connect.Tempo.Actions.WorkAttributes do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Tempo.ScopeResolver

  actions do
    action :list_work_attributes do
      id("tempo.work_attribute.list")
      resource(:work_attribute)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List work attributes")

      description(
        "List every Tempo work attribute of the site with key, name, type, required and, " <>
          "for a static list, each stored value with its label, and report the required " <>
          "attributes whose value the connector cannot describe. Fails as a whole instead " <>
          "of returning part of the list."
      )

      handler(Jido.Connect.Tempo.Handlers.Actions.ListWorkAttributes)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["tempo.worklogs.read"], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:attributes, {:array, :map},
          description:
            "Work attributes in Tempo's order, each with key (an opaque string), name, type " <>
              "(ACCOUNT, CHECKBOX, INPUT_FIELD, INPUT_NUMERIC, STATIC_LIST or another raw " <>
              "value), required, self and values: for STATIC_LIST the stored values with " <>
              "their labels, null when Tempo sent no choice list, and null for other types."
        )

        field(:complete, :boolean,
          description:
            "True when the connector can describe the value of every required attribute. " <>
              "False marks an incomplete requirement listed in incomplete, not a failed read."
        )

        field(:incomplete, {:array, :map},
          description:
            "Required attributes whose value the connector cannot describe, each with key " <>
              "and reason: unsupported_type for another type, missing_choices for a static " <>
              "list without a choice list."
        )
      end
    end
  end
end
