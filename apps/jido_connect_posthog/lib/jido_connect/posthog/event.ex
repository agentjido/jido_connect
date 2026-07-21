defmodule Jido.Connect.PostHog.Event do
  @moduledoc "Normalized PostHog event."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              event: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              distinct_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
              timestamp: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
