defmodule Jido.Connect.Intercom.Company do
  @moduledoc "Normalized Intercom company."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              workspace_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              company_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              remote_created_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              last_request_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              monthly_spend: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              session_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              user_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              segments: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              plan: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              custom_attributes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
