defmodule Jido.Connect.Zendesk.Pagination do
  @moduledoc """
  Normalized Zendesk API pagination cursor.

  Zendesk uses cursor-based pagination (CBBI) for most list endpoints and
  offset-based pagination for some legacy endpoints.

  ## Cursor-based fields

  - `after_cursor` / `before_cursor` from the `meta` envelope
  - `has_more` from the `meta` envelope
  - `next_url` / `prev_url` from the `links` envelope

  ## Offset-based fields

  - `next_page` / `previous_page` from the top-level response
  - `count` from the top-level response
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              after_cursor: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              before_cursor: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              has_more: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              next_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              prev_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              next_page: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              previous_page: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
