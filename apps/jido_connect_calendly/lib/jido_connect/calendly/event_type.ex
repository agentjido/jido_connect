defmodule Jido.Connect.Calendly.EventType do
  @moduledoc "Normalized Calendly event type."

  @schema Zoi.struct(
            __MODULE__,
            %{
              uri: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              slug: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              duration: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.default(true),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              scheduling_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              pooling_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              secret: Zoi.boolean() |> Zoi.default(false),
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
