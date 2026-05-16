defmodule Jido.Connect.PostHog.Actions.Events do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.PostHog.ScopeResolver

  actions do
    action :list_events do
      id("posthog.event.list")
      resource(:event)
      verb(:list)
      data_classification(:workspace_content)
      label("List events")
      description("List events captured in a PostHog project.")
      handler(Jido.Connect.PostHog.Handlers.Actions.ListEvents)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["events:read"], resolver: @scope_resolver)
      end

      input do
        field(:limit, :integer, default: 100, description: "Maximum number of events to return.")
        field(:offset, :integer, default: 0, description: "Pagination offset.")
        field(:event, :string, default: nil, description: "Filter by event name.")
        field(:distinct_id, :string, default: nil, description: "Filter by distinct ID.")
      end

      output do
        field(:events, {:array, :map})
        field(:next, :string)
      end
    end

    action :get_event do
      id("posthog.event.get")
      resource(:event)
      verb(:get)
      data_classification(:workspace_content)
      label("Get event")
      description("Fetch a single PostHog event by UUID.")
      handler(Jido.Connect.PostHog.Handlers.Actions.GetEvent)
      effect(:read)

      access do
        auth([:project_api_key, :personal_api_key], default: :project_api_key)
        scopes(["events:read"], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, description: "Event UUID.")

        field(:fields, {:array, :string},
          default: nil,
          description: "List of fields to return."
        )
      end

      output do
        field(:id, :string)
        field(:event, :string)
        field(:distinct_id, :string)
        field(:properties, :map)
        field(:timestamp, :string)
      end
    end
  end
end
