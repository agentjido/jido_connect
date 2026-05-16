defmodule Jido.Connect.Airtable.Record do
  @moduledoc "Normalized Airtable record."

  @schema Zoi.struct(
            __MODULE__,
            %{
              record_id: Zoi.string(),
              fields: Zoi.map() |> Zoi.default(%{}),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
