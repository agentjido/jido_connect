defmodule Jido.Connect.Calendly.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Calendly tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.
  """

  alias Jido.Connect.Catalog.Pack

  @doc "Returns all built-in Calendly catalog packs."
  def all, do: [reader(), webhook(), full()]

  @doc "Read-only Calendly discovery pack."
  def reader do
    Pack.new!(%{
      id: :calendly_reader,
      label: "Calendly reader",
      description:
        "Read Calendly event types, scheduled events, and invitees without mutation tools.",
      filters: %{provider: :calendly},
      allowed_tools: [
        "calendly.event_types.list",
        "calendly.event_types.get",
        "calendly.scheduled_events.list",
        "calendly.scheduled_events.get",
        "calendly.invitees.list",
        "calendly.invitees.get"
      ],
      metadata: %{package: :jido_connect_calendly, risk: :read}
    })
  end

  @doc "Webhook lifecycle pack."
  def webhook do
    Pack.new!(%{
      id: :calendly_webhook,
      label: "Calendly webhook manager",
      description: "Manage Calendly webhook subscriptions: create, list, and delete.",
      filters: %{provider: :calendly},
      allowed_tools: [
        "calendly.webhooks.create",
        "calendly.webhooks.list",
        "calendly.webhooks.delete"
      ],
      metadata: %{package: :jido_connect_calendly, risk: :write}
    })
  end

  @doc "Full Calendly surface pack (read, cancellation, and webhooks)."
  def full do
    Pack.new!(%{
      id: :calendly_full,
      label: "Calendly full",
      description: "Complete Calendly surface: reads, cancellation, and webhook lifecycle.",
      filters: %{provider: :calendly},
      allowed_tools: [
        "calendly.event_types.list",
        "calendly.event_types.get",
        "calendly.scheduled_events.list",
        "calendly.scheduled_events.get",
        "calendly.invitees.list",
        "calendly.invitees.get",
        "calendly.invitees.cancel",
        "calendly.webhooks.create",
        "calendly.webhooks.list",
        "calendly.webhooks.delete"
      ],
      metadata: %{package: :jido_connect_calendly, risk: :full}
    })
  end
end
