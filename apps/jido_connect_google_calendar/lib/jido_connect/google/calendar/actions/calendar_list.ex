defmodule Jido.Connect.Google.Calendar.Actions.CalendarList do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendar_list_readonly_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  actions do
    action :get_calendar_list_entry do
      id("google.calendar.calendar_list.get")
      resource(:calendar)
      verb(:get)
      data_classification(:personal_data)
      label("Get calendar list entry")
      description("Fetch one Google Calendar CalendarList entry.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.GetCalendarListEntry)
      effect(:read)

      access do
        auth(:user)
        scopes([@calendar_list_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:fields, :string)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :create_calendar_list_entry do
      id("google.calendar.calendar_list.create")
      resource(:calendar)
      verb(:create)
      data_classification(:personal_data)
      label("Create calendar list entry")
      description("Insert an existing calendar into the user's Google Calendar list.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.CreateCalendarListEntry)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:summary_override, :string)
        field(:color_id, :string)
        field(:background_color, :string)
        field(:foreground_color, :string)
        field(:color_rgb_format, :boolean)
        field(:selected, :boolean)
        field(:hidden, :boolean)
        field(:default_reminders, {:array, :map})
        field(:notification_settings, :map)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :patch_calendar_list_entry do
      id("google.calendar.calendar_list.patch")
      resource(:calendar)
      verb(:update)
      data_classification(:personal_data)
      label("Patch calendar list entry")
      description("Patch a user's Google Calendar CalendarList entry.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.PatchCalendarListEntry)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:summary_override, :string)
        field(:color_id, :string)
        field(:background_color, :string)
        field(:foreground_color, :string)
        field(:color_rgb_format, :boolean)
        field(:selected, :boolean)
        field(:hidden, :boolean)
        field(:default_reminders, {:array, :map})
        field(:notification_settings, :map)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :update_calendar_list_entry do
      id("google.calendar.calendar_list.update")
      resource(:calendar)
      verb(:update)
      data_classification(:personal_data)
      label("Update calendar list entry")
      description("Replace a user's Google Calendar CalendarList entry.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.UpdateCalendarListEntry)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:summary_override, :string)
        field(:color_id, :string)
        field(:background_color, :string)
        field(:foreground_color, :string)
        field(:color_rgb_format, :boolean)
        field(:selected, :boolean)
        field(:hidden, :boolean)
        field(:default_reminders, {:array, :map})
        field(:notification_settings, :map)
      end

      output do
        field(:calendar, :map)
      end
    end

    action :delete_calendar_list_entry do
      id("google.calendar.calendar_list.delete")
      resource(:calendar)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete calendar list entry")
      description("Remove a calendar from the user's Google Calendar list.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.DeleteCalendarListEntry)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
