defmodule Jido.Connect.Google.Meet.Space do
  @moduledoc "Normalized Google Meet meeting space metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              space_name: Zoi.string(),
              meeting_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              meeting_code: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              config: Zoi.map() |> Zoi.default(%{}),
              active_conference: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              phone_access: Zoi.list(Zoi.map()) |> Zoi.default([]),
              gateway_sip_access: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
