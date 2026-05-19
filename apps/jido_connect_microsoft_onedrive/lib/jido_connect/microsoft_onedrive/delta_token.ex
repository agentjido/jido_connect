defmodule Jido.Connect.MicrosoftOnedrive.DeltaToken do
  @moduledoc "Normalized Microsoft Graph delta query token metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              delta_token: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              delta_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
