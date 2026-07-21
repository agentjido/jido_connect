defmodule Jido.Connect.Jira.Comment do
  @moduledoc "Normalized Jira issue comment."

  alias Jido.Connect.Jira.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              rendered_body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              update_author: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              jsd_public: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
