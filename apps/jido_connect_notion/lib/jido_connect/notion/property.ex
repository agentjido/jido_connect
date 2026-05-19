defmodule Jido.Connect.Notion.Property do
  @moduledoc "Normalized Notion property value envelope."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.list(Zoi.map()) |> Zoi.default([]),
              rich_text: Zoi.list(Zoi.map()) |> Zoi.default([]),
              number: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              select: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              multi_select: Zoi.list(Zoi.map()) |> Zoi.default([]),
              date: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              people: Zoi.list(Zoi.map()) |> Zoi.default([]),
              files: Zoi.list(Zoi.map()) |> Zoi.default([]),
              checkbox: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              phone_number: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              formula: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              relation: Zoi.list(Zoi.map()) |> Zoi.default([]),
              rollup: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
