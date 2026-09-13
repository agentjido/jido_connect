defmodule Jido.Connect.Catalog.ItemSearchResult do
  @moduledoc "Ranked search result for one canonical catalog item."

  alias Jido.Connect.Catalog.Item

  @schema Zoi.struct(
            __MODULE__,
            %{
              item: Item.schema(),
              score: Zoi.integer() |> Zoi.default(0),
              matched_fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
