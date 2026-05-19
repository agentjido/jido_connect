defmodule Jido.Connect.Zendesk.Group do
  @moduledoc "Normalized Zendesk agent group."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              default: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              deleted: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
