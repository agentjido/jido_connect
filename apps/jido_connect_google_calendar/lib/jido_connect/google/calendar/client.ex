defmodule Jido.Connect.Google.Calendar.Client do
  @moduledoc "Google Calendar API client facade."

  alias Jido.Connect.Google.Calendar.Client.{
    CalendarList,
    Calendars,
    Channels,
    Acl,
    Events,
    FreeBusy,
    Settings
  }

  defdelegate get_calendar(params, access_token), to: Calendars
  defdelegate create_calendar(params, access_token), to: Calendars
  defdelegate patch_calendar(params, access_token), to: Calendars
  defdelegate update_calendar(params, access_token), to: Calendars
  defdelegate delete_calendar(params, access_token), to: Calendars
  defdelegate clear_calendar(params, access_token), to: Calendars
  defdelegate list_calendars(params, access_token), to: CalendarList
  defdelegate get_calendar_list_entry(params, access_token), to: CalendarList
  defdelegate create_calendar_list_entry(params, access_token), to: CalendarList
  defdelegate patch_calendar_list_entry(params, access_token), to: CalendarList
  defdelegate update_calendar_list_entry(params, access_token), to: CalendarList
  defdelegate delete_calendar_list_entry(params, access_token), to: CalendarList
  defdelegate watch_calendar_list(params, access_token), to: CalendarList
  defdelegate list_events(params, access_token), to: Events
  defdelegate list_event_instances(params, access_token), to: Events
  defdelegate watch_events(params, access_token), to: Events
  defdelegate get_event(params, access_token), to: Events
  defdelegate create_event(params, access_token), to: Events
  defdelegate update_event(params, access_token), to: Events
  defdelegate delete_event(params, access_token), to: Events
  defdelegate move_event(params, access_token), to: Events
  defdelegate list_acl(params, access_token), to: Acl
  defdelegate get_acl(params, access_token), to: Acl
  defdelegate create_acl(params, access_token), to: Acl
  defdelegate patch_acl(params, access_token), to: Acl
  defdelegate update_acl(params, access_token), to: Acl
  defdelegate delete_acl(params, access_token), to: Acl
  defdelegate watch_acl(params, access_token), to: Acl
  defdelegate watch_settings(params, access_token), to: Settings
  defdelegate stop_channel(params, access_token), to: Channels
  defdelegate query_free_busy(params, access_token), to: FreeBusy
end
