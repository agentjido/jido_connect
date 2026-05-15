defmodule Jido.Connect.Google.SearchConsole.URLInspection do
  @moduledoc "Normalized Google Search Console URL inspection result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              inspection_result_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              index_status: Zoi.map() |> Zoi.default(%{}),
              amp_result: Zoi.map() |> Zoi.default(%{}),
              mobile_usability_result: Zoi.map() |> Zoi.default(%{}),
              rich_results: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
