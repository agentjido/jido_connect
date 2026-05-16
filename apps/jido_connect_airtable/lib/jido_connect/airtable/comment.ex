defmodule Jido.Connect.Airtable.Comment do
  @moduledoc "Normalized Airtable record comment."

  @schema Zoi.struct(
            __MODULE__,
            %{
              comment_id: Zoi.string(),
              text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
