defmodule Jido.Connect.Calendly.Pagination do
  @moduledoc "Normalized Calendly paginated collection response."

  @schema Zoi.struct(
            __MODULE__,
            %{
              items: Zoi.list(Zoi.map()) |> Zoi.default([]),
              previous_page: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              next_page: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
