defmodule Jido.Connect.Google.Calendar.Actions.Calendars do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendar_readonly_scope "https://www.googleapis.com/auth/calendar.calendars.readonly"
  @calendar_scope "https://www.googleapis.com/auth/calendar.calendars"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :get_calendar do
      id("google.calendar.calendar.get")
      resource(:calendar)
      verb(:get)
      data_classification(:personal_data)
      label("Get calendar")
      description("Fetch metadata for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.GetCalendar)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendar_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:fields, :string)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :create_calendar do
      id("google.calendar.calendar.create")
      resource(:calendar)
      verb(:create)
      data_classification(:personal_data)
      label("Create calendar")
      description("Create a secondary Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.CreateCalendar)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_scope], resolver: @scope_resolver)
      end

      input do
        field(:summary, :string, required?: true)
        field(:description, :string)
        field(:location, :string)
        field(:time_zone, :string)
        field(:conference_properties, :map)
        field(:auto_accept_invitations, :boolean)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :patch_calendar do
      id("google.calendar.calendar.patch")
      resource(:calendar)
      verb(:update)
      data_classification(:personal_data)
      label("Patch calendar")
      description("Patch metadata for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.PatchCalendar)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:summary, :string)
        field(:description, :string)
        field(:location, :string)
        field(:time_zone, :string)
        field(:conference_properties, :map)
        field(:auto_accept_invitations, :boolean)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :update_calendar do
      id("google.calendar.calendar.update")
      resource(:calendar)
      verb(:update)
      data_classification(:personal_data)
      label("Update calendar")
      description("Replace metadata for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.UpdateCalendar)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:summary, :string, required?: true)
        field(:description, :string)
        field(:location, :string)
        field(:time_zone, :string)
        field(:conference_properties, :map)
        field(:auto_accept_invitations, :boolean)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :delete_calendar do
      id("google.calendar.calendar.delete")
      resource(:calendar)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete calendar")
      description("Delete a secondary Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.DeleteCalendar)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@calendar_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true)
      end

      output do
        field(:result, :map)
      end
    end

    action :clear_calendar do
      id("google.calendar.calendar.clear")
      resource(:calendar)
      verb(:clear)
      data_classification(:personal_data)
      label("Clear calendar")
      description("Clear all events from the user's primary Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.ClearCalendar)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@calendar_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
