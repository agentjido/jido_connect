defmodule Jido.Connect.MicrosoftCalendar.Location do
  @moduledoc """
  Normalized Microsoft Calendar location metadata.

  Maps from Microsoft Graph `location` resources to a stable,
  provider-agnostic struct. Stores display name, address, and
  coordinates — no raw Microsoft Graph extension data.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              address: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              coordinates: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
