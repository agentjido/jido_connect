defmodule Jido.Connect.Google.Slides.Slide do
  @moduledoc "Normalized Google Slides slide/page metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              object_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              slide_layout: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              master_object_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              layout_object_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              elements:
                Zoi.list(Jido.Connect.Google.Slides.PageElement.schema()) |> Zoi.default([]),
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
