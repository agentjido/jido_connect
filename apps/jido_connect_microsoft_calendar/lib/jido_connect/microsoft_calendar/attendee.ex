defmodule Jido.Connect.MicrosoftCalendar.Attendee do
  @moduledoc """
  Normalized Microsoft Calendar attendee metadata.

  Maps from Microsoft Graph `attendee` resources to a stable,
  provider-agnostic struct. Stores display name, address, type, and
  response status — no raw response payload.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              address: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
