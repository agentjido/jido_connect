defmodule Jido.Connect.PostHog.FeatureFlag do
  @moduledoc "Normalized PostHog feature flag."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              key: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              rollout_percentage: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              filters: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
