defmodule Jido.Connect.Jira.Actions.Metadata do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Jira.ScopeResolver

  actions do
    action :list_field_schemas do
      id("jira.field_schema.list")
      resource(:field_schema)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List field schemas")
      description("List all Jira field schemas (system and custom) for the instance.")
      handler(Jido.Connect.Jira.Handlers.Actions.ListFieldSchemas)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["read:jira-work", "read:jira-configuration"], resolver: @scope_resolver)
      end

      input do
        field(:expand, :string,
          default: nil,
          description: "Comma-separated list of fields to expand (e.g. 'schema')"
        )
      end

      output do
        field(:fields, {:array, :map})
        field(:total, :integer)
      end
    end
  end
end
