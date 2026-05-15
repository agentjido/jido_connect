defmodule Jido.Connect.Google.Forms.Form do
  @moduledoc "Normalized Google Forms form metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              form_id: Zoi.string(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              form_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              editor_file_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              revision_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              linked_sheet_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              published: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              items: Zoi.list(Jido.Connect.Google.Forms.QuestionItem.schema()) |> Zoi.default([]),
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
