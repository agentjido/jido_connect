defmodule Jido.Connect.GitLab.Label do
  @moduledoc "Normalized GitLab label."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text_color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
