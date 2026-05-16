defmodule Jido.Connect.Salesforce.Pagination do
  @moduledoc "Normalized Salesforce SOQL query pagination cursor."

  @schema Zoi.struct(
            __MODULE__,
            %{
              total_size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              done: Zoi.boolean() |> Zoi.default(true),
              next_records_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
