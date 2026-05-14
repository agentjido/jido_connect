defmodule Jido.Connect.Google.Calendar.Client do
  @moduledoc "Google Calendar API client facade."

  alias Jido.Connect.Google.Calendar.Client.{
    Acl,
    CalendarList,
    Channels,
    Events,
    FreeBusy,
    Settings
  }

  defdelegate list_calendars(params, access_token), to: CalendarList
  defdelegate watch_calendar_list(params, access_token), to: CalendarList
  defdelegate list_events(params, access_token), to: Events
  defdelegate watch_events(params, access_token), to: Events
  defdelegate get_event(params, access_token), to: Events
  defdelegate create_event(params, access_token), to: Events
  defdelegate update_event(params, access_token), to: Events
  defdelegate delete_event(params, access_token), to: Events
  defdelegate watch_acl(params, access_token), to: Acl
  defdelegate watch_settings(params, access_token), to: Settings
  defdelegate stop_channel(params, access_token), to: Channels
  defdelegate query_free_busy(params, access_token), to: FreeBusy
end
