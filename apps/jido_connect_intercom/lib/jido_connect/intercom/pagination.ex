defmodule Jido.Connect.Intercom.Pagination do
  @moduledoc """
  Normalized Intercom scroll-based pagination cursor.

  Intercom list endpoints return a top-level `pages` envelope with a
  `next` field containing a scroll cursor. When `next` is `nil` or
  absent, the result set is complete.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              next: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              page: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              per_page: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              total_pages: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              total_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
