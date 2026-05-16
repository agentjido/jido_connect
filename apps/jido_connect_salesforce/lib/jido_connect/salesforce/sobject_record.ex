defmodule Jido.Connect.Salesforce.SObjectRecord do
  @moduledoc "Normalized generic Salesforce SObject record."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              attributes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              fields: Zoi.map() |> Zoi.default(%{}),
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
