defmodule Jido.Connect.MicrosoftCalendar.CatalogPacks do
  @moduledoc "Curated catalog packs for common Microsoft Calendar tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "microsoft.calendar.calendars.list",
    "microsoft.calendar.events.list",
    "microsoft.calendar.schedule.get"
  ]

  @triage_tools @metadata_tools ++
                  [
                    "microsoft.calendar.calendar.get",
                    "microsoft.calendar.event.get",
                    "microsoft.calendar.meeting_times.find"
                  ]

  @write_tools @metadata_tools ++
                 [
                   "microsoft.calendar.event.create",
                   "microsoft.calendar.event.update"
                 ]

  @destructive_tools @metadata_tools ++
                       [
                         "microsoft.calendar.event.delete"
                       ]

  @doc "Returns all built-in Microsoft Calendar catalog packs."
  def all, do: [metadata(), triage(), write(), destructive()]

  @doc "Read-only Microsoft Calendar metadata pack."
  def metadata do
    Pack.new!(%{
      id: :microsoft_calendar_metadata,
      label: "Microsoft Calendar metadata",
      description:
        "Read Microsoft Calendar calendar and event list metadata without mutation tools.",
      filters: %{provider: :microsoft_calendar},
      allowed_tools: @metadata_tools,
      metadata: %{package: :jido_connect_microsoft_calendar, risk: :read}
    })
  end

  @doc "Microsoft Calendar triage pack for reading calendar and event details."
  def triage do
    Pack.new!(%{
      id: :microsoft_calendar_triage,
      label: "Microsoft Calendar triage",
      description:
        "Read Microsoft Calendar calendars and events in detail. Excludes event mutation and delete tools.",
      filters: %{provider: :microsoft_calendar},
      allowed_tools: @triage_tools,
      metadata: %{
        package: :jido_connect_microsoft_calendar,
        excludes: [
          "microsoft.calendar.event.create",
          "microsoft.calendar.event.update",
          "microsoft.calendar.event.delete"
        ]
      }
    })
  end

  @doc "Microsoft Calendar write pack for event create and update workflows."
  def write do
    Pack.new!(%{
      id: :microsoft_calendar_write,
      label: "Microsoft Calendar write",
      description:
        "Read Microsoft Calendar metadata and create or update events. Excludes delete tools.",
      filters: %{provider: :microsoft_calendar},
      allowed_tools: @write_tools,
      metadata: %{
        package: :jido_connect_microsoft_calendar,
        excludes: [
          "microsoft.calendar.calendar.get",
          "microsoft.calendar.event.get",
          "microsoft.calendar.event.delete"
        ]
      }
    })
  end

  @doc "Microsoft Calendar destructive pack for explicit event delete workflows."
  def destructive do
    Pack.new!(%{
      id: :microsoft_calendar_destructive,
      label: "Microsoft Calendar destructive",
      description:
        "Read Microsoft Calendar metadata and expose explicit event delete operations.",
      filters: %{provider: :microsoft_calendar},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_microsoft_calendar, risk: :destructive}
    })
  end
end
