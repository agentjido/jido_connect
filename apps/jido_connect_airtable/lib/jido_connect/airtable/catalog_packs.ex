defmodule Jido.Connect.Airtable.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Airtable tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:airtable_reader` | read | base schema and record queries |
  | `:airtable_editor` | write | reader + record create, update, delete |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @base_read_tools [
    "airtable.bases.list",
    "airtable.bases.get"
  ]

  @record_read_tools [
    "airtable.records.list",
    "airtable.records.get"
  ]

  @reader_tools @base_read_tools ++
                  @record_read_tools

  @record_write_tools [
    "airtable.records.create",
    "airtable.records.update",
    "airtable.records.delete"
  ]

  @editor_tools @reader_tools ++
                  @record_write_tools

  @doc "Returns all built-in Airtable catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Airtable pack for base schema and record queries."
  def reader do
    Pack.new!(%{
      id: :airtable_reader,
      label: "Airtable reader",
      description: "Read Airtable base schemas and records without mutation tools.",
      filters: %{provider: :airtable},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_airtable, risk: :read}
    })
  end

  @doc "Airtable editor pack for read, record create, update, and delete."
  def editor do
    Pack.new!(%{
      id: :airtable_editor,
      label: "Airtable editor",
      description:
        "Read Airtable base schemas and records, plus create, update, and delete records.",
      filters: %{provider: :airtable},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_airtable, risk: :write}
    })
  end
end
