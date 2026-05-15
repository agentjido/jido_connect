defmodule Jido.Connect.Calcom.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Cal.com tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:calcom_reader` | read | event type and booking queries |
  | `:calcom_booking` | write | reader + booking cancel / reschedule |
  | `:calcom_webhook` | write | reader + webhook CRUD |
  | `:calcom_full` | write | all Cal.com action tools |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "calcom.event_types.list",
    "calcom.bookings.list",
    "calcom.bookings.get"
  ]

  @booking_tools @reader_tools ++
                   [
                     "calcom.bookings.cancel",
                     "calcom.bookings.reschedule"
                   ]

  @webhook_tools @reader_tools ++
                   [
                     "calcom.webhooks.create",
                     "calcom.webhooks.list",
                     "calcom.webhooks.delete"
                   ]

  @full_tools @booking_tools ++
                [
                  "calcom.webhooks.create",
                  "calcom.webhooks.list",
                  "calcom.webhooks.delete"
                ]

  @doc "Returns all built-in Cal.com catalog packs."
  def all, do: [reader(), booking(), webhook(), full()]

  @doc "Read-only Cal.com discovery pack for event types and bookings."
  def reader do
    Pack.new!(%{
      id: :calcom_reader,
      label: "Cal.com reader",
      description: "Read Cal.com event types and bookings without mutation tools.",
      filters: %{provider: :calcom},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_calcom, risk: :read}
    })
  end

  @doc "Cal.com booking pack for event type discovery and booking management."
  def booking do
    Pack.new!(%{
      id: :calcom_booking,
      label: "Cal.com booking",
      description:
        "Read Cal.com event types and bookings, plus cancel and reschedule booking actions.",
      filters: %{provider: :calcom},
      allowed_tools: @booking_tools,
      metadata: %{package: :jido_connect_calcom, risk: :write}
    })
  end

  @doc "Cal.com webhook pack for webhook endpoint lifecycle management."
  def webhook do
    Pack.new!(%{
      id: :calcom_webhook,
      label: "Cal.com webhook",
      description:
        "Read Cal.com event types and bookings, plus manage webhook endpoint lifecycle.",
      filters: %{provider: :calcom},
      allowed_tools: @webhook_tools,
      metadata: %{package: :jido_connect_calcom, risk: :write}
    })
  end

  @doc "Cal.com full pack with all action tools."
  def full do
    Pack.new!(%{
      id: :calcom_full,
      label: "Cal.com full",
      description: "All Cal.com action tools: event types, bookings, and webhooks.",
      filters: %{provider: :calcom},
      allowed_tools: @full_tools,
      metadata: %{package: :jido_connect_calcom, risk: :write}
    })
  end
end
