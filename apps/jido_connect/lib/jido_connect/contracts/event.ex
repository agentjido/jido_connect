defmodule Jido.Connect.Event do
  @moduledoc """
  Minimal host-owned execution event record.

  `new/1` and `new!/1` validate the shape but do not redact `payload` or
  `metadata`. The host must remove secrets before it stores, logs, or exposes
  an event. There is no public serialization helper for this record.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              run_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              trigger_event_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.any(),
              timestamp: Zoi.datetime(),
              payload: Zoi.map() |> Zoi.default(%{}),
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
