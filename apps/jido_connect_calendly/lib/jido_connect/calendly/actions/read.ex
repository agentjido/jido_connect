defmodule Jido.Connect.Calendly.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calendly.ScopeResolver

  actions do
    # -----------------------------------------------------------------------
    # Event type actions
    # -----------------------------------------------------------------------

    action :list_event_types do
      id("calendly.event_types.list")
      resource(:event_type)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List event types")

      description(
        "List Calendly event types with optional user/organization scope and pagination."
      )

      handler(Jido.Connect.Calendly.Handlers.Actions.ListEventTypes)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:user_uri, :string)
        field(:organization_uri, :string)
        field(:active, :boolean)
        field(:count, :integer, default: 20)
        field(:page_token, :string)
        field(:sort, :string)
      end

      output do
        field(:event_types, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :get_event_type do
      id("calendly.event_types.get")
      resource(:event_type)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get event type")
      description("Fetch a single Calendly event type by URI.")
      handler(Jido.Connect.Calendly.Handlers.Actions.GetEventType)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:uri, :string, required?: true)
      end

      output do
        field(:event_type, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Scheduled event actions
    # -----------------------------------------------------------------------

    action :list_scheduled_events do
      id("calendly.scheduled_events.list")
      resource(:scheduled_event)
      verb(:list)
      data_classification(:personal_data)
      label("List scheduled events")
      description("List Calendly scheduled events with optional date filters and pagination.")
      handler(Jido.Connect.Calendly.Handlers.Actions.ListScheduledEvents)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:user_uri, :string)
        field(:organization_uri, :string)
        field(:status, :string)
        field(:min_start_time, :string)
        field(:max_start_time, :string)
        field(:count, :integer, default: 20)
        field(:page_token, :string)
        field(:sort, :string)
      end

      output do
        field(:scheduled_events, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :get_scheduled_event do
      id("calendly.scheduled_events.get")
      resource(:scheduled_event)
      verb(:get)
      data_classification(:personal_data)
      label("Get scheduled event")
      description("Fetch a single Calendly scheduled event by URI.")
      handler(Jido.Connect.Calendly.Handlers.Actions.GetScheduledEvent)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:uri, :string, required?: true)
      end

      output do
        field(:scheduled_event, :map)
      end
    end

    # -----------------------------------------------------------------------
    # Invitee actions
    # -----------------------------------------------------------------------

    action :list_invitees do
      id("calendly.invitees.list")
      resource(:invitee)
      verb(:list)
      data_classification(:personal_data)
      label("List invitees")
      description("List Calendly invitees for a given scheduled event.")
      handler(Jido.Connect.Calendly.Handlers.Actions.ListInvitees)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:event_uri, :string, required?: true)
        field(:status, :string)
        field(:count, :integer, default: 20)
        field(:page_token, :string)
        field(:sort, :string)
      end

      output do
        field(:invitees, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :get_invitee do
      id("calendly.invitees.get")
      resource(:invitee)
      verb(:get)
      data_classification(:personal_data)
      label("Get invitee")
      description("Fetch a single Calendly invitee by event URI and invitee URI.")
      handler(Jido.Connect.Calendly.Handlers.Actions.GetInvitee)
      effect(:read)

      access do
        auth(:personal_access_token)
        scopes([], resolver: @scope_resolver)
      end

      input do
        field(:event_uri, :string, required?: true)
        field(:uri, :string, required?: true)
      end

      output do
        field(:invitee, :map)
      end
    end
  end
end
