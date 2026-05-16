defmodule Jido.Connect.Linear.Comment do
  @moduledoc "Normalized Linear issue comment."

  alias Jido.Connect.Linear.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              parent_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
