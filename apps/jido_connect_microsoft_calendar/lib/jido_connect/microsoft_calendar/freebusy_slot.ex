defmodule Jido.Connect.MicrosoftCalendar.FreeBusySlot do
  @moduledoc """
  Normalized Microsoft Calendar free/busy time slot.

  Maps from Microsoft Graph `scheduleItem` resources (returned by the
  `calendar/getSchedule` endpoint) to a stable, provider-agnostic
  struct. Stores start/end times and availability status.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              start: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              end: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
