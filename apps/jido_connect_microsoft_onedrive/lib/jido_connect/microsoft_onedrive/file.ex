defmodule Jido.Connect.MicrosoftOnedrive.FileFacet do
  @moduledoc "Normalized Microsoft Graph `file` facet metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              hashes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
