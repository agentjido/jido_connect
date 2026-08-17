defmodule Jido.Connect.Field do
  @moduledoc "Input, output, config, and signal field contract."

  @schema Zoi.struct(
            __MODULE__,
            %{
              __spark_metadata__: Zoi.any() |> Zoi.optional(),
              name: Zoi.atom(),
              type: Zoi.any(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              example: Zoi.any() |> Zoi.optional(),
              default: Zoi.any() |> Zoi.optional(),
              enum: Zoi.list(Zoi.any()) |> Zoi.nullish() |> Zoi.optional(),
              minimum: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              maximum: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              min_length: Zoi.integer() |> Zoi.min(0) |> Zoi.nullish() |> Zoi.optional(),
              max_length: Zoi.integer() |> Zoi.min(0) |> Zoi.nullish() |> Zoi.optional(),
              required?: Zoi.boolean() |> Zoi.default(false),
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
