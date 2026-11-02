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
  | `:tempo_writer` | write | the confirmation-gated create of the connected account's own worklog |

  The two read packs hold no mutation. The writer pack holds only
  `tempo.worklog.create`, which requires confirmation; a host commits it
  through `Jido.Connect.prepare/4` and `Jido.Connect.commit/4`.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools ["tempo.worklogs.list_own"]
  @period_lookup_tools ["tempo.period.bookability.get"]
  @writer_tools ["tempo.worklog.create"]

  @doc "Returns all built-in Tempo catalog packs."
  def all, do: [reader(), period_lookup(), writer()]

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

  @doc "Tempo writer pack with the confirmation-gated create of an own worklog."
  def writer do
    Pack.new!(%{
      id: :tempo_writer,
      label: "Tempo writer",
      description:
        "Create one worklog of the connected account after confirmation, without read tools.",
      filters: %{provider: :tempo},
      allowed_tools: @writer_tools,
      metadata: %{package: :jido_connect_tempo, risk: :write}
    })
  end
end
