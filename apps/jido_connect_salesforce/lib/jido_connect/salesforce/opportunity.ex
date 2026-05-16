defmodule Jido.Connect.Salesforce.Opportunity do
  @moduledoc "Normalized Salesforce CRM opportunity."

  @schema Zoi.struct(
            __MODULE__,
            %{
              opportunity_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              amount: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              stage: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              probability: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              close_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              currency: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              account_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
