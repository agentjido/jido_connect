defmodule Jido.Connect.MicrosoftOnedrive.Folder do
  @moduledoc "Normalized Microsoft Graph `folder` facet metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              child_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              view: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
