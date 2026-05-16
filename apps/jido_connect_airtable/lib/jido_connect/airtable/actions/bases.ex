defmodule Jido.Connect.Airtable.Actions.Bases do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Airtable.ScopeResolver

  actions do
    action :list_bases do
      id("airtable.bases.list")
      resource(:base)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List bases")
      description("List all accessible Airtable bases.")
      handler(Jido.Connect.Airtable.Handlers.Actions.ListBases)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes(["schema.bases:read"], resolver: @scope_resolver)
      end

      input do
        field(:offset, :string)
      end

      output do
        field(:bases, {:array, :map})
      end
    end

    action :get_base do
      id("airtable.bases.get")
      resource(:base)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get base")
      description("Fetch the schema for a specific Airtable base.")
      handler(Jido.Connect.Airtable.Handlers.Actions.GetBase)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes(["schema.bases:read"], resolver: @scope_resolver)
      end

      input do
        field(:base_id, :string, required?: true, example: "appXXXXXXXXXXXX")
      end

      output do
        field(:base, :map)
      end
    end
  end
end
