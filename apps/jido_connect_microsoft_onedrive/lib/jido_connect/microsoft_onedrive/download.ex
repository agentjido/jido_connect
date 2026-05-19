defmodule Jido.Connect.MicrosoftOnedrive.Download do
  @moduledoc "Normalized Microsoft Graph download metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              download_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              content_length: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              content_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
