defmodule Jido.Connect.Google.Forms.QuestionItem do
  @moduledoc "Normalized Google Forms question/item metadata."

  @known_question_types MapSet.new(~w(
    text
    text_paragraph
    multiple_choice
    checkbox
    dropdown
    scale
    date
    time
    duration
    image
    video
    file_upload
    row_question
    grid
  ))

  @schema Zoi.struct(
            __MODULE__,
            %{
              item_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              image: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              video: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              question_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              question_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              required: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              question_details: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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

  @doc "Returns the set of known Google Forms question types."
  def known_question_types, do: @known_question_types
end
