defmodule Jido.Connect.PostHog.Person do
  @moduledoc "Normalized PostHog person."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              distinct_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
