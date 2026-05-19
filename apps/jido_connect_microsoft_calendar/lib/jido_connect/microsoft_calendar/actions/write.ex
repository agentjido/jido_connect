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
        field(:content_type, :string, default: "text")
        field(:start_date_time, :string, required?: true)
        field(:end_date_time, :string, required?: true)
        field(:time_zone, :string, default: "UTC")
        field(:location, :string)
        field(:attendees, {:array, :string}, default: [])
        field(:is_all_day, :boolean)
        field(:sensitivity, :string)
        field(:show_as, :string)
        field(:recurrence, :map)
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
        field(:content_type, :string)
        field(:start_date_time, :string)
        field(:end_date_time, :string)
        field(:time_zone, :string)
        field(:location, :string)
        field(:attendees, {:array, :string})
        field(:is_all_day, :boolean)
        field(:sensitivity, :string)
        field(:show_as, :string)
      end

      output do
        field(:event, :map)
      end
    end

    action :accept_event do
      id("microsoft.calendar.event.accept")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Accept Microsoft Calendar event")
      description("Accept a Microsoft Calendar event invitation with an optional comment.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.AcceptEvent)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string)
      end

      output do
        field(:accepted, :boolean)
        field(:event_id, :string)
      end
    end

    action :decline_event do
      id("microsoft.calendar.event.decline")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Decline Microsoft Calendar event")
      description("Decline a Microsoft Calendar event invitation with an optional comment.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeclineEvent)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string)
      end

      output do
        field(:declined, :boolean)
        field(:event_id, :string)
      end
    end

    action :tentatively_accept_event do
      id("microsoft.calendar.event.tentatively_accept")
      resource(:event)
      verb(:update)
      data_classification(:personal_data)
      label("Tentatively accept Microsoft Calendar event")

      description(
        "Tentatively accept a Microsoft Calendar event invitation with an optional comment."
      )

      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.TentativelyAcceptEvent)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string)
      end

      output do
        field(:tentatively_accepted, :boolean)
        field(:event_id, :string)
      end
    end
  end
end
