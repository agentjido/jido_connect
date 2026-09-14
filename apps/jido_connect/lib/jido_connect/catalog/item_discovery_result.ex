defmodule Jido.Connect.Catalog.ItemDiscoveryResult do
  @moduledoc "Catalog item result with diagnostics for entry and item projection failures."

  alias Jido.Connect.Catalog.{Diagnostic, Item}

  @schema Zoi.struct(
            __MODULE__,
            %{
              items: Zoi.list(Item.schema()) |> Zoi.default([]),
              diagnostics: Zoi.list(Diagnostic.schema()) |> Zoi.default([])
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
