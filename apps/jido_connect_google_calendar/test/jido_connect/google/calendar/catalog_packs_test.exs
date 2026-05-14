defmodule Jido.Connect.Google.Calendar.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Calendar

  defmodule FakeCalendarClient do
    def watch_events(
          %{
            calendar_id: "primary",
            channel_id: "event-channel",
            address: "https://example.com/calendar/events",
            channel_type: "web_hook"
          },
          "token"
        ) do
      {:ok,
       Calendar.Channel.new!(%{
         channel_id: "event-channel",
         resource_id: "events-resource",
         resource_uri: "https://www.googleapis.com/calendar/v3/calendars/primary/events"
       })}
    end

    def create_event(
          %{
            calendar_id: "primary",
            summary: "Planning",
            start: "2026-05-06T09:00:00-05:00",
            end: "2026-05-06T10:00:00-05:00",
            all_day: false,
            attendees: [],
            recurrence: []
          },
          "token"
        ) do
      {:ok,
       Calendar.Event.new!(%{
         event_id: "created123",
         calendar_id: "primary",
         summary: "Planning",
         start: "2026-05-06T09:00:00-05:00",
         end: "2026-05-06T10:00:00-05:00"
       })}
    end
  end

  test "reader pack exposes read, availability, and poll tools only" do
    results =
      Catalog.search_tools("calendar",
        modules: [Calendar],
        packs: Calendar.catalog_packs(),
        pack: :google_calendar_reader
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.calendar.calendar.list" in ids
    assert "google.calendar.event.get" in ids
    assert "google.calendar.availability.find" in ids
    assert "google.calendar.event.changed" in ids
    assert "google.calendar.event.changed.push" in ids
    refute "google.calendar.event.create" in ids
    refute "google.calendar.event.watch" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.calendar.event.get",
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_reader
             )

    assert descriptor.tool.id == "google.calendar.event.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.calendar.event.create",
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_reader
             )
  end

  test "scheduler pack allows event scheduling operations" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.calendar.event.create",
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_scheduler
             )

    assert descriptor.tool.id == "google.calendar.event.create"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.calendar.event.delete",
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_scheduler
             )

    assert descriptor.tool.id == "google.calendar.event.delete"
  end

  test "watch pack exposes channel lifecycle actions" do
    results =
      Catalog.search_tools("calendar",
        modules: [Calendar],
        packs: Calendar.catalog_packs(),
        pack: :google_calendar_watch
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.calendar.event.watch" in ids
    assert "google.calendar.calendar_list.watch" in ids
    assert "google.calendar.acl.watch" in ids
    assert "google.calendar.settings.watch" in ids
    assert "google.calendar.channel.stop" in ids
    assert "google.calendar.event.changed.push" in ids
    refute "google.calendar.event.create" in ids
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{event: %{event_id: "created123"}}} =
             Catalog.call_tool(
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 summary: "Planning",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00"
               },
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_scheduler,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.calendar.event.create",
               %{
                 calendar_id: "primary",
                 summary: "Planning",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00"
               },
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_reader,
               context: context,
               credential_lease: lease
             )
  end

  test "watch pack allows channel lifecycle calls" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/calendar.events.readonly"
        ]
      )

    assert {:ok, %{channel: %{channel_id: "event-channel"}}} =
             Catalog.call_tool(
               "google.calendar.event.watch",
               %{
                 calendar_id: "primary",
                 channel_id: "event-channel",
                 address: "https://example.com/calendar/events"
               },
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_watch,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.calendar.event.watch",
               %{
                 calendar_id: "primary",
                 channel_id: "event-channel",
                 address: "https://example.com/calendar/events"
               },
               modules: [Calendar],
               packs: Calendar.catalog_packs(),
               pack: :google_calendar_reader,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/calendar.events"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_calendar_client: FakeCalendarClient},
        scopes: scopes
      })

    {context, lease}
  end
end
