defmodule Jido.Connect.MicrosoftCalendar.CalendarGroup do
  @moduledoc """
  Normalized Microsoft Calendar group metadata.

  Maps from Microsoft Graph `calendarGroup` resources to a stable,
  provider-agnostic struct. Calendar groups organize calendars into
  logical collections.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              group_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              class_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              change_key: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              calendar_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
