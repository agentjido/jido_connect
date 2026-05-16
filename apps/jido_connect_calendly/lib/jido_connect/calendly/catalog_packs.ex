defmodule Jido.Connect.Calendly.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Calendly tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.
  """

  alias Jido.Connect.Catalog.Pack

  @doc "Returns all built-in Calendly catalog packs."
  def all, do: [reader()]

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
end
