defmodule Jido.Connect.PostHog.Actions.Persons do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :list_persons do
      id("posthog.person.list")
      resource(:person)
      verb(:list)
      data_classification(:workspace_content)
      label("List persons")
      description("List persons in a PostHog project.")
      handler(Jido.Connect.PostHog.Handlers.Actions.ListPersons)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["persons:read"], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer, default: 100, description: "Maximum number of persons to return.")
        field(:offset, :integer, default: 0, description: "Pagination offset.")
        field(:search, :string, default: nil, description: "Search persons by email or name.")
      end

      output do
        field(:persons, {:array, :map})
        field(:next, :string)
      end
    end

    action :get_person do
      id("posthog.person.get")
      resource(:person)
      verb(:get)
      data_classification(:workspace_content)
      label("Get person")
      description("Fetch a single PostHog person by distinct ID.")
      handler(Jido.Connect.PostHog.Handlers.Actions.GetPerson)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["persons:read"], resolver: @scope_resolver)
      end

      input do
        field(:distinct_id, :string, required?: true, description: "Person distinct ID.")

        field(:fields, {:array, :string},
          default: nil,
          description: "List of fields to return."
        )
      end

      output do
        field(:id, :string)
        field(:distinct_ids, {:array, :string})
        field(:properties, :map)
        field(:created_at, :string)
      end
    end
  end
end
