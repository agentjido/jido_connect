defmodule Jido.Connect.Notion.Block do
  @moduledoc "Normalized Notion content block."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_edited_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              has_children: Zoi.boolean() |> Zoi.default(false),
              archived: Zoi.boolean() |> Zoi.default(false),
              in_trash: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              parent: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              rich_text: Zoi.list(Zoi.map()) |> Zoi.default([]),
              children: Zoi.list(Zoi.map()) |> Zoi.default([]),
              heading: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              paragraph: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              bulleted_list_item: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              numbered_list_item: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              to_do: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              toggle: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              code: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              quote: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              callout: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              divider: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              image: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              file: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              embed: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              bookmark: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              table: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              table_row: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              unsupported: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
