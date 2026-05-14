defmodule Jido.Connect.Google.Calendar.ScopeResolver do
  @moduledoc """
  Resolves Google Calendar scopes.

  Calendar-list reads and event reads use separate narrow Google scopes. Broader
  Calendar grants are accepted when hosts already have them.
  """

  @calendar_scope "https://www.googleapis.com/auth/calendar"
  @calendar_readonly_scope "https://www.googleapis.com/auth/calendar.readonly"
  @calendar_list_write_scope "https://www.googleapis.com/auth/calendar.calendarlist"
  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @acl_scope "https://www.googleapis.com/auth/calendar.acls"
  @acl_readonly_scope "https://www.googleapis.com/auth/calendar.acls.readonly"
  @settings_readonly_scope "https://www.googleapis.com/auth/calendar.settings.readonly"
  @freebusy_scope "https://www.googleapis.com/auth/calendar.freebusy"
  @events_freebusy_scope "https://www.googleapis.com/auth/calendar.events.freebusy"
  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @events_scope "https://www.googleapis.com/auth/calendar.events"
  @calendar_list_actions [
    "google.calendar.calendar.list",
    "google.calendar.calendar_list.watch",
    "google.calendar.calendar_list.changed.push"
  ]
  @freebusy_actions [
    "google.calendar.freebusy.query",
    "google.calendar.availability.find"
  ]
  @event_watch_actions [
    "google.calendar.event.watch",
    "google.calendar.event.changed.push"
  ]
  @acl_actions [
    "google.calendar.acl.watch",
    "google.calendar.acl.changed.push"
  ]
  @settings_actions [
    "google.calendar.settings.watch",
    "google.calendar.setting.changed.push"
  ]
  @channel_stop_actions ["google.calendar.channel.stop"]
  @write_actions [
    "google.calendar.event.create",
    "google.calendar.event.update",
    "google.calendar.event.delete"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @calendar_list_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @calendar_list_write_scope in scopes -> [@calendar_list_write_scope]
      @calendar_list_scope in scopes -> [@calendar_list_scope]
      true -> [@calendar_list_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @calendar_list_actions do
    [@calendar_list_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @event_watch_actions and is_list(scopes) do
    event_watch_scope(scopes)
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @event_watch_actions do
    [@events_readonly_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @acl_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @acl_scope in scopes -> [@acl_scope]
      @acl_readonly_scope in scopes -> [@acl_readonly_scope]
      true -> [@acl_readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @acl_actions do
    [@acl_readonly_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @settings_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @settings_readonly_scope in scopes -> [@settings_readonly_scope]
      true -> [@settings_readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @settings_actions do
    [@settings_readonly_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @channel_stop_actions and is_list(scopes) do
    any_calendar_scope(scopes)
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @channel_stop_actions do
    [@events_readonly_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @freebusy_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @events_freebusy_scope in scopes -> [@events_freebusy_scope]
      @freebusy_scope in scopes -> [@freebusy_scope]
      true -> [@events_freebusy_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @freebusy_actions do
    [@events_freebusy_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @write_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @events_scope in scopes -> [@events_scope]
      true -> [@events_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @write_actions do
    [@events_scope]
  end

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    event_read_scope(scopes)
  end

  defp required_for_operation(_operation_id, _connection), do: [@events_readonly_scope]

  defp event_read_scope(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @events_scope in scopes -> [@events_scope]
      true -> [@events_readonly_scope]
    end
  end

  defp event_watch_scope(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @events_scope in scopes -> [@events_scope]
      @events_readonly_scope in scopes -> [@events_readonly_scope]
      @events_freebusy_scope in scopes -> [@events_freebusy_scope]
      true -> [@events_readonly_scope]
    end
  end

  defp any_calendar_scope(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @events_scope in scopes -> [@events_scope]
      @events_readonly_scope in scopes -> [@events_readonly_scope]
      @events_freebusy_scope in scopes -> [@events_freebusy_scope]
      @calendar_list_write_scope in scopes -> [@calendar_list_write_scope]
      @calendar_list_scope in scopes -> [@calendar_list_scope]
      @acl_scope in scopes -> [@acl_scope]
      @acl_readonly_scope in scopes -> [@acl_readonly_scope]
      @settings_readonly_scope in scopes -> [@settings_readonly_scope]
      true -> [@events_readonly_scope]
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
