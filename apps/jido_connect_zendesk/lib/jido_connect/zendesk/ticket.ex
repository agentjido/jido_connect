defmodule Jido.Connect.Zendesk.Ticket do
  @moduledoc "Normalized Zendesk ticket."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              priority: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              requester_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              assignee_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              group_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              organization_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.list(Zoi.string()) |> Zoi.default([]),
              custom_fields: Zoi.list(Zoi.map()) |> Zoi.default([]),
              due_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              external_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              brand_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              form_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              via: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              satisfaction_rating: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
