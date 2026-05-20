defmodule Jido.Connect.GitLab.Pagination do
  @moduledoc "Normalized GitLab REST API pagination envelope."

  @schema Zoi.struct(
            __MODULE__,
            %{
              page: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              per_page: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              total: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              total_pages: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              next_page: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              prev_page: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
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
