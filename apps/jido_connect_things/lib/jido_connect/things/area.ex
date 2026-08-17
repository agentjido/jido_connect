defmodule Jido.Connect.Things.Area do
  @moduledoc "Normalized Things area retained by the V1 state reader."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(min_length: 1, max_length: 32),
              entity_version: Zoi.string() |> Zoi.default("Area3"),
              title: Zoi.string(max_length: 2_000) |> Zoi.default(""),
              position: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              tag_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              deleted: Zoi.boolean() |> Zoi.default(false),
              state_complete: Zoi.boolean() |> Zoi.default(true),
              last_server_index: Zoi.integer() |> Zoi.default(0),
              unknown_fields: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true,
            unrecognized_keys: :error
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new(attrs), do: Zoi.parse(@schema, attrs)
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
end
