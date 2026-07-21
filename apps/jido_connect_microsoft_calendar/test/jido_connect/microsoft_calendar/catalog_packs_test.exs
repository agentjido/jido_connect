defmodule Jido.Connect.MicrosoftCalendar.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.MicrosoftCalendar

  test "metadata pack exposes only read tools" do
    results =
      Catalog.search_tools("calendar",
        modules: [MicrosoftCalendar],
        packs: MicrosoftCalendar.catalog_packs(),
        pack: :microsoft_calendar_metadata
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "microsoft.calendar.calendars.list" in ids
    assert "microsoft.calendar.events.list" in ids
    assert "microsoft.calendar.schedule.get" in ids
    refute "microsoft.calendar.calendar.get" in ids
    refute "microsoft.calendar.event.get" in ids
    refute "microsoft.calendar.meeting_times.find" in ids
    refute "microsoft.calendar.event.create" in ids
    refute "microsoft.calendar.event.update" in ids
    refute "microsoft.calendar.event.delete" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.calendar.calendars.list",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_metadata
             )

    assert descriptor.tool.id == "microsoft.calendar.calendars.list"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.calendar.event.create",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_metadata
             )
  end

  test "triage pack allows read and detail tools and rejects write and delete" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.get",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )

    assert descriptor.tool.id == "microsoft.calendar.event.get"

    assert {:ok, calendar_descriptor} =
             Catalog.describe_tool("microsoft.calendar.calendar.get",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )

    assert calendar_descriptor.tool.id == "microsoft.calendar.calendar.get"

    assert {:ok, schedule_descriptor} =
             Catalog.describe_tool("microsoft.calendar.schedule.get",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )

    assert schedule_descriptor.tool.id == "microsoft.calendar.schedule.get"

    assert {:ok, meeting_times_descriptor} =
             Catalog.describe_tool("microsoft.calendar.meeting_times.find",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )

    assert meeting_times_descriptor.tool.id == "microsoft.calendar.meeting_times.find"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.calendar.event.create",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.calendar.event.delete",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_triage
             )
  end

  test "write pack allows create, update, and RSVP tools and rejects destructive" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.create",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )

    assert descriptor.tool.id == "microsoft.calendar.event.create"

    assert {:ok, update_descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.update",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )

    assert update_descriptor.tool.id == "microsoft.calendar.event.update"

    assert {:ok, accept_descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.accept",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )

    assert accept_descriptor.tool.id == "microsoft.calendar.event.accept"

    assert {:ok, decline_descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.decline",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )

    assert decline_descriptor.tool.id == "microsoft.calendar.event.decline"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.calendar.event.delete",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.calendar.event.cancel",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_write
             )
  end

  test "destructive pack exposes delete and cancel tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.delete",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_destructive
             )

    assert descriptor.tool.id == "microsoft.calendar.event.delete"

    assert {:ok, cancel_descriptor} =
             Catalog.describe_tool("microsoft.calendar.event.cancel",
               modules: [MicrosoftCalendar],
               packs: MicrosoftCalendar.catalog_packs(),
               pack: :microsoft_calendar_destructive
             )

    assert cancel_descriptor.tool.id == "microsoft.calendar.event.cancel"
  end
end
