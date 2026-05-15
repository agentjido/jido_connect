defmodule Jido.Connect.HubSpot.Pagination do
  @moduledoc "Normalized HubSpot API pagination cursor."

  @schema Zoi.struct(
            __MODULE__,
            %{
              after: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              before: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              total_page: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              page_size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
