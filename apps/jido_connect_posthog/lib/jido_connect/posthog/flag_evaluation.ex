defmodule Jido.Connect.PostHog.FlagEvaluation do
  @moduledoc "Normalized PostHog feature flag evaluation result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              flag_key: Zoi.string(),
              enabled: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              variant: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              payload: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
