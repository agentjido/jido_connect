defmodule Jido.Connect.Google.Analytics.PropertySummary do
  @moduledoc "Normalized Google Analytics property summary metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              property: Zoi.string(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              property_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              parent: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              account: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
