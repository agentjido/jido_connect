defmodule Jido.Connect.Google.Slides.Thumbnail do
  @moduledoc "Normalized Google Slides thumbnail metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              width: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              height: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              content_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
