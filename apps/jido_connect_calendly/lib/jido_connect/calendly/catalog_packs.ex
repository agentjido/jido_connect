defmodule Jido.Connect.Calendly.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Calendly tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  The scaffold provides an empty reader pack. Additional packs will be added
  as action capabilities are implemented.
  """

  alias Jido.Connect.Catalog.Pack

  @doc "Returns all built-in Calendly catalog packs."
  def all, do: [reader()]

  @doc "Read-only Calendly discovery pack."
  def reader do
    Pack.new!(%{
      id: :calendly_reader,
      label: "Calendly reader",
      description: "Read Calendly event types and scheduled events without mutation tools.",
      filters: %{provider: :calendly},
      allowed_tools: [],
      metadata: %{package: :jido_connect_calendly, risk: :read}
    })
  end
end
