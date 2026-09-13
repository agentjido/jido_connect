defmodule Jido.Connect.Run do
  @moduledoc """
  Minimal host-owned action or trigger execution record.

  `new/1` and `new!/1` validate the shape but do not redact `actor` or
  `metadata`. The host must remove secrets before it stores, logs, or exposes
  a run. There is no public serialization helper for this record.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              integration_id: Zoi.atom(),
              operation_id: Zoi.string(),
              tenant_id: Zoi.string(),
              actor: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              connection_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              input_hash: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.atom(),
              inserted_at: Zoi.datetime(),
              updated_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
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
