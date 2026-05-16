defmodule Jido.Connect.PostHog.QueryResult do
  @moduledoc "Normalized PostHog HogQL query result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              query: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              columns: Zoi.list(Zoi.string()) |> Zoi.default([]),
              results: Zoi.list(Zoi.map()) |> Zoi.default([]),
              has_more: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
