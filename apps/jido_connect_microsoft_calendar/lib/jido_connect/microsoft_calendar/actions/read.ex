defmodule Jido.Connect.MicrosoftCalendar.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendars_read "Calendars.Read"
  @scope_resolver Jido.Connect.MicrosoftCalendar.ScopeResolver

  actions do
    action :list_calendars do
      id("microsoft.calendar.calendars.list")
      resource(:calendar)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft Calendars")
      description("List Microsoft Calendar calendars for the authenticated user.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendars)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:calendars, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_calendar do
      id("microsoft.calendar.calendar.get")
      resource(:calendar)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft Calendar")
      description("Fetch a single Microsoft Calendar by id.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendar)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:calendar, :map)
      end
    end

    action :list_events do
      id("microsoft.calendar.events.list")
      resource(:event)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft Calendar events")
      description("List Microsoft Calendar events for a given calendar.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEvents)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string)
        field(:start_date_time, :string)
        field(:end_date_time, :string)
        field(:page_size, :integer, default: 25)
        field(:skip, :integer)
      end

      output do
        field(:events, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_event do
      id("microsoft.calendar.event.get")
      resource(:event)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft Calendar event")
      description("Fetch a single Microsoft Calendar event by id.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEvent)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:calendar_id, :string)
      end

      output do
        field(:event, :map)
      end
    end

    action :get_schedule do
      id("microsoft.calendar.schedule.get")
      resource(:schedule)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft Calendar free/busy schedule")

      description(
        "Get free/busy availability for users or resources via Microsoft Graph calendar/getSchedule."
      )

      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetSchedule)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:schedules, {:array, :string},
          required?: true,
          example: ["meganb@contoso.com", "brianj@contoso.com"]
        )

        field(:start_date_time, :string,
          required?: true,
          example: "2026-06-15T09:00:00"
        )

        field(:end_date_time, :string,
          required?: true,
          example: "2026-06-15T18:00:00"
        )

        field(:time_zone, :string, default: "UTC")
        field(:availability_view_interval, :integer, default: 30)
      end

      output do
        field(:results, {:array, :map})
      end
    end

    action :find_meeting_times do
      id("microsoft.calendar.meeting_times.find")
      resource(:meeting_time)
      verb(:get)
      data_classification(:personal_data)
      label("Find Microsoft Calendar meeting times")

      description(
        "Suggest meeting times based on attendee availability via Microsoft Graph findMeetingTimes."
      )

      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.FindMeetingTimes)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendars_read], resolver: @scope_resolver)
      end

      input do
        field(:attendees, {:array, :string},
          example: ["meganb@contoso.com", "brianj@contoso.com"]
        )

        field(:start_date_time, :string, example: "2026-06-15T09:00:00")
        field(:end_date_time, :string, example: "2026-06-15T18:00:00")
        field(:time_zone, :string, default: "UTC")
        field(:meeting_duration, :string, default: "PT1H")
        field(:is_org_app_required, :boolean)
        field(:return_suggestion_reasons, :boolean, default: true)
        field(:minimum_attendee_percentage, :integer)
      end

      output do
        field(:suggestions, {:array, :map})
        field(:empty_suggestions_reason, :string)
      end
    end
  end
end
