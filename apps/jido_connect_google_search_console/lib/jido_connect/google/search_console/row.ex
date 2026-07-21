defmodule Jido.Connect.Google.SearchConsole.Row do
  @moduledoc "Normalized Google Search Console search analytics row."

  @schema Zoi.struct(
            __MODULE__,
            %{
              keys: Zoi.list(Zoi.string()) |> Zoi.default([]),
              clicks: Zoi.integer() |> Zoi.default(0),
              impressions: Zoi.integer() |> Zoi.default(0),
              ctr: Zoi.float() |> Zoi.default(0.0),
              position: Zoi.float() |> Zoi.default(0.0),
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
