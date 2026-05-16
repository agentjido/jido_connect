defmodule Jido.Connect.PostHog.Pagination do
  @moduledoc "Normalized PostHog REST API pagination envelope."

  @schema Zoi.struct(
            __MODULE__,
            %{
              next: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              previous: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
