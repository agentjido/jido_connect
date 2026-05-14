defmodule Jido.Connect.Google.Analytics.Dimension do
  @moduledoc "Normalized Google Analytics dimension descriptor or row value."

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string(),
              value: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              category: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              custom?: Zoi.boolean() |> Zoi.default(false),
              deprecated?: Zoi.boolean() |> Zoi.default(false),
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
