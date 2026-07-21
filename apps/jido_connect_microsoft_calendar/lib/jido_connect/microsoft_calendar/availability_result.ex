defmodule Jido.Connect.MicrosoftCalendar.AvailabilityResult do
  @moduledoc """
  Normalized Microsoft Calendar availability / free-busy result for a single
  schedule information item.

  Maps from Microsoft Graph `scheduleInformation` resources to a stable,
  provider-agnostic struct. Each result corresponds to one queried user or
  resource and contains a list of `FreeBusySlot` entries and any errors.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              schedule_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              availability_view: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              slots: Zoi.list(Zoi.map()) |> Zoi.default([]),
              error: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
