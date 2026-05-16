defmodule Jido.Connect.Jira.Pagination do
  @moduledoc "Normalized Jira REST API pagination envelope."

  @schema Zoi.struct(
            __MODULE__,
            %{
              start_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              max_results: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              total: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              is_last: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              next_page_token: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
