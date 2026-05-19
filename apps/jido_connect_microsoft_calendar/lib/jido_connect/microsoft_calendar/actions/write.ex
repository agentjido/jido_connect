defmodule Jido.Connect.MicrosoftCalendar.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendars_read_write "Calendars.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftCalendar.ScopeResolver

  actions do
    action :create_event do
      id("microsoft.calendar.event.create")
      resource(:event)
      verb(:create)
      data_classification(:personal_data)
      label("Create Microsoft Calendar event")
      description("Create a new event in a Microsoft Calendar.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.CreateEvent)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string)
        field(:subject, :string, required?: true)
        field(:body, :string)
        field(:start_date_time, :string, required?: true)
        field(:end_date_time, :string, required?: true)
        field(:time_zone, :string, default: "UTC")
        field(:location, :string)
        field(:attendees, {:array, :string}, default: [])
      end

      output do
        field(:event, :map)
      end
    end

    action :update_event do
      id("microsoft.calendar.event.update")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Update Microsoft Calendar event")
      description("Update an existing Microsoft Calendar event.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.UpdateEvent)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:calendar_id, :string)
        field(:subject, :string)
        field(:body, :string)
        field(:start_date_time, :string)
        field(:end_date_time, :string)
        field(:time_zone, :string)
        field(:location, :string)
        field(:attendees, {:array, :string})
      end

      output do
        field(:event, :map)
      end
    end
  end
end
