defmodule Jido.Connect.Salesforce.Account do
  @moduledoc "Normalized Salesforce CRM account."

  @schema Zoi.struct(
            __MODULE__,
            %{
              account_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              industry: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              billing_city: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              billing_state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              billing_country: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              phone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              website: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              number_of_employees: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              annual_revenue: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              attributes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
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
