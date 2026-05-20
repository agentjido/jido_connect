defmodule Jido.Connect.GitLab.Note do
  @moduledoc "Normalized GitLab note (comment)."

  alias Jido.Connect.GitLab.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              attachment: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              noteable_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              noteable_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              system: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
