defmodule Jido.Connect.Notion.ParentRef do
  @moduledoc "Normalized Notion parent reference."

  @schema Zoi.struct(
            __MODULE__,
            %{
              type: Zoi.string(),
              workspace: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              page_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              database_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              block_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
