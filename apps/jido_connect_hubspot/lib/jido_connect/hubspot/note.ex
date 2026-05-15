defmodule Jido.Connect.HubSpot.Note do
  @moduledoc "Normalized HubSpot CRM note (engagement)."

  @schema Zoi.struct(
            __MODULE__,
            %{
              note_id: Zoi.string(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              contact_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              company_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              deal_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              ticket_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              engagement_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
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
