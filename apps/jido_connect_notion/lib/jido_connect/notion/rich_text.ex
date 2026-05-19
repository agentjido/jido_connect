defmodule Jido.Connect.Notion.RichText do
  @moduledoc "Normalized Notion rich text segment."

  @schema Zoi.struct(
            __MODULE__,
            %{
              type: Zoi.string() |> Zoi.default("text"),
              plain_text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              href: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              annotations: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              text: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              mention: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              equation: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
