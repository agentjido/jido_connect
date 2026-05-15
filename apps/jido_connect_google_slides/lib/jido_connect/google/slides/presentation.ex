defmodule Jido.Connect.Google.Slides.Presentation do
  @moduledoc "Normalized Google Slides presentation metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              presentation_id: Zoi.string(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              revision_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              page_width: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              page_height: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              slides: Zoi.list(Jido.Connect.Google.Slides.Slide.schema()) |> Zoi.default([]),
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
