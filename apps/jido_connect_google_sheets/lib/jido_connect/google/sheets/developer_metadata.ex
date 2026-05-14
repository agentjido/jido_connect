defmodule Jido.Connect.Google.Sheets.DeveloperMetadata do
  @moduledoc "Normalized Google Sheets developer metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              metadata_id: Zoi.integer(),
              metadata_key: Zoi.string(),
              metadata_value: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.map() |> Zoi.default(%{}),
              visibility: Zoi.string(),
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
