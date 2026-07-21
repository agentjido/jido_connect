defmodule Jido.Connect.Notion.Database do
  @moduledoc "Normalized Notion database."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_edited_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.list(Zoi.map()) |> Zoi.default([]),
              description: Zoi.list(Zoi.map()) |> Zoi.default([]),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              public_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              is_inline: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              parent: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
              cover: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              icon: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
