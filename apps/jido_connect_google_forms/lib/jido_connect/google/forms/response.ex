defmodule Jido.Connect.Google.Forms.Response do
  @moduledoc "Normalized Google Forms response metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              response_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              form_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              respondent_email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              create_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_submitted_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              total_score: Zoi.float() |> Zoi.nullish() |> Zoi.optional(),
              answers: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
