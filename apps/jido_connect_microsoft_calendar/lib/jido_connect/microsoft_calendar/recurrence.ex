defmodule Jido.Connect.MicrosoftCalendar.Recurrence do
  @moduledoc """
  Normalized Microsoft Calendar recurrence pattern metadata.

  Maps from Microsoft Graph `patternedRecurrence` resources to a stable,
  provider-agnostic struct. Stores the recurrence pattern and range
  definitions — no raw Microsoft Graph extension data.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              pattern: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              range: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
