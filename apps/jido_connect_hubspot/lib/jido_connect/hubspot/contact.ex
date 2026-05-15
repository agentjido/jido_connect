defmodule Jido.Connect.HubSpot.Contact do
  @moduledoc "Normalized HubSpot CRM contact."

  @schema Zoi.struct(
            __MODULE__,
            %{
              contact_id: Zoi.string(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              first_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              phone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              company: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              job_title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              website: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              lifecycle_stage: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
              archived_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
              associations: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
