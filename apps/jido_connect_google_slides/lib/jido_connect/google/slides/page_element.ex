defmodule Jido.Connect.Google.Slides.PageElement do
  @moduledoc "Normalized Google Slides page element metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              object_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              element_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              transform: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
