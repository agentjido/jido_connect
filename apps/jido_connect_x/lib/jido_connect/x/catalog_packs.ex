defmodule Jido.Connect.X.CatalogPacks do
  @moduledoc "Curated X reader pack."

  alias Jido.Connect.Catalog.Pack
  alias Jido.Connect.X.Contract

  @reader_tools Enum.map(Contract.actions(), & &1.id)

  def all, do: [reader()]

  def reader do
    Pack.new!(%{
      id: :x_reader,
      label: "X reader",
      description: "Read the verified X account, bookmarks, and posts.",
      filters: %{provider: :x},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_x, risk: :read}
    })
  end
end
