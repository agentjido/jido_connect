defmodule Jido.Connect.Notion.Comment do
  @moduledoc "Normalized Notion discussion comment."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              discussion_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_edited_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              rich_text: Zoi.list(Zoi.map()) |> Zoi.default([]),
              parent: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
