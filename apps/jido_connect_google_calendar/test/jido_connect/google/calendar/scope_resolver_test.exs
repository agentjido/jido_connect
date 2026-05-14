defmodule Jido.Connect.Google.Calendar.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

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

  test "declares Calendar read, broad, mutation, and legacy-compatible scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing event grant falls back to event read scope",
        operation: "google.calendar.event.get",
        granted: [],
        expected: @events_readonly_scope
      },
      %{
        label: "calendar list uses narrow CalendarList scope",
        operation: "google.calendar.calendar.list",
        granted: [],
        expected: @calendar_list_scope
      },
      %{
        label: "broad calendar readonly grant can satisfy calendar list",
        operation: "google.calendar.calendar.list",
        granted: [@calendar_readonly_scope],
        expected: @calendar_readonly_scope
      },
      %{
        label: "calendar list watch accepts narrow write grant",
        operation: "google.calendar.calendar_list.watch",
        granted: [@calendar_list_write_scope],
        expected: @calendar_list_write_scope
      },
      %{
        label: "broad calendar grant can satisfy event reads",
        operation: "google.calendar.event.list",
        granted: [@calendar_scope],
        expected: @calendar_scope
      },
      %{
        label: "event write grant can satisfy event reads",
        operation: "google.calendar.event.get",
        granted: [@events_scope],
        expected: @events_scope
      },
      %{
        label: "freebusy uses narrow events.freebusy scope by default",
        operation: "google.calendar.freebusy.query",
        granted: [],
        expected: @events_freebusy_scope
      },
      %{
        label: "legacy calendar.freebusy grant remains accepted",
        operation: "google.calendar.availability.find",
        granted: [@freebusy_scope],
        expected: @freebusy_scope
      },
      %{
        label: "event mutation requires events write scope",
        operation: "google.calendar.event.update",
        granted: [@events_readonly_scope],
        expected: @events_scope
      },
      %{
        label: "event watch accepts events freebusy scope from Google watch docs",
        operation: "google.calendar.event.watch",
        granted: [@events_freebusy_scope],
        expected: @events_freebusy_scope
      },
      %{
        label: "acl watch uses narrow ACL readonly scope",
        operation: "google.calendar.acl.watch",
        granted: [],
        expected: @acl_readonly_scope
      },
      %{
        label: "acl watch accepts ACL write scope",
        operation: "google.calendar.acl.changed.push",
        granted: [@acl_scope],
        expected: @acl_scope
      },
      %{
        label: "settings watch uses settings readonly scope",
        operation: "google.calendar.settings.watch",
        granted: [],
        expected: @settings_readonly_scope
      },
      %{
        label: "channel stop accepts any Calendar scope that owns the channel",
        operation: "google.calendar.channel.stop",
        granted: [@settings_readonly_scope],
        expected: @settings_readonly_scope
      },
      %{
        label: "broad calendar grant can satisfy mutations",
        operation: "google.calendar.event.delete",
        granted: [@calendar_scope],
        expected: @calendar_scope
      }
    ])
  end
end
