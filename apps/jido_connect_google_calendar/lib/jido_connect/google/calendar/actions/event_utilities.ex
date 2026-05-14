defmodule Jido.Connect.Google.Calendar.Actions.EventUtilities do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @events_scope "https://www.googleapis.com/auth/calendar.events"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :list_event_instances do
      id("google.calendar.event.instances")
      resource(:event)
      verb(:list)
      data_classification(:personal_data)
      label("List event instances")
      description("List instances of a recurring Google Calendar event.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.ListEventInstances)
      effect(:read)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string, required?: true)
        field(:page_size, :integer, default: 250)
        field(:page_token, :string)
        field(:fields, :string)
        field(:time_min, :string)
        field(:time_max, :string)
        field(:time_zone, :string)
        field(:original_start, :string)
        field(:show_deleted, :boolean, default: false)
        field(:max_attendees, :integer)
      end

      output do
        field(:events, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end

    action :move_event do
      id("google.calendar.event.move")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Move event")
      description("Move a default Google Calendar event to another calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.MoveEvent)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@events_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:event_id, :string, required?: true)
        field(:destination_calendar_id, :string, required?: true)
        field(:send_updates, :string, enum: ["all", "externalOnly", "none"])
        field(:send_notifications, :boolean)
      end

      output do
        field(:event, :map)
      end
    end
  end
end
