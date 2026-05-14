defmodule Jido.Connect.Google.Calendar.Channel do
  @moduledoc "Normalized Google Calendar push notification channel metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              channel_id: Zoi.string(),
              resource_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              token: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              expiration: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              address: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              params: Zoi.map() |> Zoi.default(%{}),
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
