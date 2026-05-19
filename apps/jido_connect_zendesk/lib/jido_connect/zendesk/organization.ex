defmodule Jido.Connect.Zendesk.Organization do
  @moduledoc "Normalized Zendesk organization."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              domain_names: Zoi.list(Zoi.string()) |> Zoi.default([]),
              details: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              group_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.list(Zoi.string()) |> Zoi.default([]),
              external_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              shared_tickets: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              shared_comments: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
