defmodule Jido.Connect.Google.Analytics.Report do
  @moduledoc "Normalized Google Analytics report response."

  alias Jido.Connect.Google.Analytics.{Dimension, Metric, Row}

  @schema Zoi.struct(
            __MODULE__,
            %{
              property: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              dimension_headers: Zoi.list(Dimension.schema()) |> Zoi.default([]),
              metric_headers: Zoi.list(Metric.schema()) |> Zoi.default([]),
              rows: Zoi.list(Row.schema()) |> Zoi.default([]),
              totals: Zoi.list(Row.schema()) |> Zoi.default([]),
              maximums: Zoi.list(Row.schema()) |> Zoi.default([]),
              minimums: Zoi.list(Row.schema()) |> Zoi.default([]),
              row_count: Zoi.integer() |> Zoi.default(0),
              currency_code: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{}),
              property_quota: Zoi.map() |> Zoi.default(%{})
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
