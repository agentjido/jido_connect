defmodule Jido.Connect.Notion.Pagination do
  @moduledoc "Normalized Notion cursor-based pagination envelope."

  @schema Zoi.struct(
            __MODULE__,
            %{
              has_more: Zoi.boolean() |> Zoi.default(false),
              next_cursor: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
