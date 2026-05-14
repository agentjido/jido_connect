defmodule Jido.Connect.Google.Calendar.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Calendar tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "google.calendar.calendar.list",
    "google.calendar.event.list",
    "google.calendar.event.get",
    "google.calendar.freebusy.query",
    "google.calendar.availability.find",
    "google.calendar.event.changed",
    "google.calendar.event.changed.push",
    "google.calendar.calendar_list.changed.push",
    "google.calendar.acl.changed.push",
    "google.calendar.setting.changed.push"
  ]

  @watch_tools @reader_tools ++
                 [
                   "google.calendar.event.watch",
                   "google.calendar.calendar_list.watch",
                   "google.calendar.acl.watch",
                   "google.calendar.settings.watch",
                   "google.calendar.channel.stop"
                 ]

  @scheduler_tools @reader_tools ++
                     [
                       "google.calendar.event.create",
                       "google.calendar.event.update",
                       "google.calendar.event.delete"
                     ]

  @doc "Returns all built-in Google Calendar catalog packs."
  def all, do: [reader(), scheduler(), watch()]

  @doc "Read-only Calendar pack for calendar/event reads, freebusy, availability, and polling."
  def reader do
    Pack.new!(%{
      id: :google_calendar_reader,
      label: "Google Calendar reader",
      description:
        "Read calendars and events, query free/busy windows, find availability, and poll event changes.",
      filters: %{provider: :google_calendar},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_google_calendar, risk: :read}
    })
  end

  @doc "Calendar scheduling pack with read, availability, and event mutation tools."
  def scheduler do
    Pack.new!(%{
      id: :google_calendar_scheduler,
      label: "Google Calendar scheduler",
      description:
        "Read Calendar context, find availability, and create, update, or delete events.",
      filters: %{provider: :google_calendar},
      allowed_tools: @scheduler_tools,
      metadata: %{package: :jido_connect_google_calendar, risk: :write}
    })
  end

  @doc "Calendar watch channel lifecycle pack for push notification setup."
  def watch do
    Pack.new!(%{
      id: :google_calendar_watch,
      label: "Google Calendar watch",
      description:
        "Read Calendar metadata, discover Calendar webhooks, and manage Calendar push notification channels.",
      filters: %{provider: :google_calendar},
      allowed_tools: @watch_tools,
      metadata: %{package: :jido_connect_google_calendar, risk: :write}
    })
  end
end
