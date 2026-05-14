defmodule Jido.Connect.Google.Analytics.Row do
  @moduledoc "Normalized Google Analytics report row."

  alias Jido.Connect.Google.Analytics.{Dimension, Metric}

  @schema Zoi.struct(
            __MODULE__,
            %{
              dimensions: Zoi.list(Dimension.schema()) |> Zoi.default([]),
              metrics: Zoi.list(Metric.schema()) |> Zoi.default([]),
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
