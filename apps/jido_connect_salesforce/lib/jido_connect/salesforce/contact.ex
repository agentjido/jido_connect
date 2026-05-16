defmodule Jido.Connect.Salesforce.Contact do
  @moduledoc "Normalized Salesforce CRM contact."

  @schema Zoi.struct(
            __MODULE__,
            %{
              contact_id: Zoi.string(),
              first_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              phone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              account_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              mailing_address: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
