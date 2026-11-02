defmodule Jido.Connect.Tempo.CatalogPacks do
  @moduledoc """
  Curated catalog packs for Tempo tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:tempo_reader` | read | the connected account's own worklogs |
  | `:tempo_period_lookup` | read | the connected account's period approval evidence |

  Neither pack holds a mutation.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools ["tempo.worklogs.list_own"]
  @period_lookup_tools ["tempo.period.bookability.get"]

  @doc "Returns all built-in Tempo catalog packs."
  def all, do: [reader(), period_lookup()]

  @doc "Read-only Tempo pack."
  def reader do
    Pack.new!(%{
      id: :tempo_reader,
      label: "Tempo reader",
      description: "Read the connected account's own Tempo worklogs without mutation tools.",
      filters: %{provider: :tempo},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_tempo, risk: :read}
    })
  end

  @doc "Read-only Tempo pack for the approval evidence of periods."
  def period_lookup do
    Pack.new!(%{
      id: :tempo_period_lookup,
      label: "Tempo period lookup",
      description:
        "Read the connected account's approval evidence for Tempo periods without mutation tools.",
      filters: %{provider: :tempo},
      allowed_tools: @period_lookup_tools,
      metadata: %{package: :jido_connect_tempo, risk: :read}
    })
  end
end
