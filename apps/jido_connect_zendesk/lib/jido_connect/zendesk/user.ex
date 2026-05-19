defmodule Jido.Connect.Zendesk.User do
  @moduledoc "Normalized Zendesk user."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              role: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              verified: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              organization_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              phone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              photo: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.list(Zoi.string()) |> Zoi.default([]),
              external_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              alias: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              details: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
