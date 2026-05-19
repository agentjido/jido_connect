defmodule Jido.Connect.MicrosoftCalendarTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftCalendar

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts

  @calendar_action_modules [
    Jido.Connect.MicrosoftCalendar.Actions.ListCalendars,
    Jido.Connect.MicrosoftCalendar.Actions.GetCalendar,
    Jido.Connect.MicrosoftCalendar.Actions.ListEvents,
    Jido.Connect.MicrosoftCalendar.Actions.GetEvent,
    Jido.Connect.MicrosoftCalendar.Actions.GetSchedule,
    Jido.Connect.MicrosoftCalendar.Actions.FindMeetingTimes,
    Jido.Connect.MicrosoftCalendar.Actions.CreateEvent,
    Jido.Connect.MicrosoftCalendar.Actions.UpdateEvent,
    Jido.Connect.MicrosoftCalendar.Actions.DeleteEvent
  ]

  @calendar_dsl_fragments [
    Jido.Connect.MicrosoftCalendar.Actions.Read,
    Jido.Connect.MicrosoftCalendar.Actions.Write,
    Jido.Connect.MicrosoftCalendar.Actions.Destructive
  ]

  test "declares Microsoft Calendar provider metadata" do
    spec = MicrosoftCalendar.integration()

    assert spec.id == :microsoft_calendar
    assert spec.package == :jido_connect_microsoft_calendar
    assert spec.name == "Microsoft Calendar"
    assert spec.category == :calendar
    assert spec.tags == [:microsoft, :calendar, :scheduling, :productivity]

    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftCalendar,
      id_prefix: "microsoft.calendar.",
      pack_id_prefix: "microsoft_calendar_",
      module_namespace: Jido.Connect.MicrosoftCalendar
    )

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "Calendars.Read" in profile.optional_scopes
    assert "Calendars.ReadWrite" in profile.optional_scopes
    assert "Calendars.Read.Shared" in profile.optional_scopes
    assert "Calendars.ReadWrite.Shared" in profile.optional_scopes

    assert Enum.map(spec.actions, & &1.id) == [
             "microsoft.calendar.calendars.list",
             "microsoft.calendar.calendar.get",
             "microsoft.calendar.events.list",
             "microsoft.calendar.event.get",
             "microsoft.calendar.schedule.get",
             "microsoft.calendar.meeting_times.find",
             "microsoft.calendar.event.create",
             "microsoft.calendar.event.update",
             "microsoft.calendar.event.delete"
           ]

    create_action = Enum.find(spec.actions, &(&1.id == "microsoft.calendar.event.create"))
    assert create_action.risk == :external_write
    assert create_action.confirmation == :required_for_ai

    update_action = Enum.find(spec.actions, &(&1.id == "microsoft.calendar.event.update"))
    assert update_action.risk == :write
    assert update_action.confirmation == :required_for_ai

    delete_action = Enum.find(spec.actions, &(&1.id == "microsoft.calendar.event.delete"))
    assert delete_action.risk == :destructive
    assert delete_action.confirmation == :always
  end

  test "compiles generated Jido modules for actions and plugin" do
    ConnectorContracts.assert_generated_surface(MicrosoftCalendar,
      otp_app: :jido_connect_microsoft_calendar,
      action_modules: @calendar_action_modules,
      sensor_specs: [],
      plugin_module: Jido.Connect.MicrosoftCalendar.Plugin,
      plugin_name: "microsoft_calendar"
    )

    ConnectorContracts.assert_catalog_pack_delegates(MicrosoftCalendar,
      metadata_pack: :microsoft_calendar_metadata,
      triage_pack: :microsoft_calendar_triage,
      write_pack: :microsoft_calendar_write,
      destructive_pack: :microsoft_calendar_destructive
    )

    ConnectorContracts.assert_plugin_tool_availability(MicrosoftCalendar)
  end

  test "loads Calendar Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@calendar_dsl_fragments)
  end

  test "resolves Calendar scopes for read and write actions" do
    resolver = Jido.Connect.MicrosoftCalendar.ScopeResolver

    ConnectorContracts.assert_scope_resolver_shape(resolver, ["Calendars.Read"])

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.event.create"},
             %{},
             %{scopes: ["Calendars.ReadWrite"]}
           ) == ["Calendars.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.event.update"},
             %{},
             %{scopes: ["Calendars.ReadWrite"]}
           ) == ["Calendars.ReadWrite"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.calendars.list"},
             %{},
             %{scopes: ["Calendars.Read"]}
           ) == ["Calendars.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.event.get"},
             %{},
             %{scopes: ["Calendars.Read"]}
           ) == ["Calendars.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.schedule.get"},
             %{},
             %{scopes: ["Calendars.Read"]}
           ) == ["Calendars.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.meeting_times.find"},
             %{},
             %{scopes: ["Calendars.Read"]}
           ) == ["Calendars.Read"]

    assert resolver.required_scopes(
             %{id: "microsoft.calendar.event.delete"},
             %{},
             %{scopes: ["Calendars.ReadWrite"]}
           ) == ["Calendars.ReadWrite"]

    assert resolver.required_scopes(%{}, %{}, %{}) == ["Calendars.Read"]
  end

  test "read handlers return missing_access_token without credentials" do
    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendars.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendar.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEvents.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEvent.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetSchedule.run(%{}, %{})

    assert {:error, :missing_access_token} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.FindMeetingTimes.run(%{}, %{})
  end

  test "write and destructive shell handlers return not implemented" do
    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.CreateEvent.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.UpdateEvent.run(%{}, %{})

    assert {:error, :not_implemented} ==
             Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeleteEvent.run(%{}, %{})
  end
end
